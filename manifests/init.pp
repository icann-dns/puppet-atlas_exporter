# @summary Sets up a Prometheus exporter for RIPE Atlas checks.
# @url https://github.com/czerwonk/atlas_exporter
# @param atlas_measurements A hash of measurment id and the timeout for the measurement.
#   The exporter will export the latest value for each measurement ID.
# @param exporter_port The port on which the exporter should listen.
# @param config_file The path to the configuration file for the exporter.
# @param filter_invalid Whether to filter out invalid measurements
# @param histogram_buckets A hash of histogram type and the buckets to use for that histogram
class atlas_exporter (
  Hash[Integer, Atlas_exporter::Timeout]        $atlas_measurements,
  Stdlib::Port                                  $exporter_port     = 9400,
  Stdlib::Unixpath                              $config_file       = '/etc/prometheus-atlas-exporter/config.yaml',
  Boolean                                       $filter_invalid    = true,
  Hash[Atlas_exporter::Histogram, Array[Float]] $histogram_buckets = {}
) {
  # Ubuntu Packages available from
  # https://github.com/icann-dns/prometheus-atlas-exporter-deb/releases
  # Debian packages available from
  # https://apt.wikimedia.org/wikimedia/pool/main/p/prometheus-atlas-exporter/
  stdlib::ensure_packages('prometheus-atlas-exporter')

  $config_file.dirname.extlib::mkdir_p()

  $config = {
    'measurements' => $atlas_measurements.map |$id, $timeout| {{ 'id' => $id, 'timeout' => $timeout } },
    'filter_invalid_results' => $filter_invalid,
    'histogram_buckets' => Hash($histogram_buckets.map |$type, $buckets| { [$type, { 'rtt' => $buckets }] }),
  }

  file { $config_file:
    ensure  => 'file',
    content => stdlib::to_yaml($config),
    owner   => 'prometheus',
    notify  => Service['prometheus-atlas-exporter'],
  }

  service { 'prometheus-atlas-exporter':
    ensure  => 'running',
    require => Package['prometheus-atlas-exporter'],
  }
}
