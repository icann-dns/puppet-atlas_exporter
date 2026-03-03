# @summary Sets up a Prometheus exporter for RIPE Atlas checks.
# @url https://github.com/czerwonk/atlas_exporter
# @param atlas_measurements A hash of measurment id and the timeout for the measurement.
#   The exporter will export the latest value for each measurement ID.
# @param enable Whether to enable the exporter service.
# @param port The port on which the exporter should listen.
# @param filter_invalid Whether to filter out invalid measurements
# @param cache_cleanup The interval in seconds to clean up the cache
# @param cache_ttl The time to live in seconds for cached measurements
# @param config_file The path to the configuration file for the exporter.
# @param log_level The log level for the exporter
# @param metrics_go Whether to export Go runtime metrics
# @param metrics_process Whether to export process metrics
# @param profiling Whether to enable pprof profiling endpoints
# @param streaming Whether to enable streaming of measurements
# @param streaming_buffer_size The buffer size for streaming measurements
# @param streaming_timeout The timeout for streaming measurements
# @param timeout The timeout for fetching measurements
# @param tls_enabled Whether to enable TLS for the exporter
# @param tls_cert_file The path to the TLS certificate file (required if tls_enabled is true)
# @param tls_key_file The path to the TLS key file (required if tls_enabled is true)
# @param worker_count The number of worker threads to use for fetching measurements
# @param histogram_buckets A hash of histogram type and the buckets to use for that histogram
class atlas_exporter (
  Hash[Integer, Atlas_exporter::Timeout]          $atlas_measurements,
  Boolean                                         $enable                = true,
  Boolean                                         $filter_invalid        = true,
  Integer                                         $cache_cleanup         = 300,
  Integer                                         $cache_ttl             = 3600,
  Stdlib::Unixpath                                $config_file           = '/etc/prometheus-atlas-exporter/config.yml',
  Enum['debug', 'info', 'warn', 'error', 'fatal'] $log_level             = 'info',
  Boolean                                         $metrics_go            = true,
  Boolean                                         $metrics_process       = true,
  Boolean                                         $profiling             = false,
  Boolean                                         $streaming             = true,
  Integer                                         $streaming_buffer_size = 100,
  Atlas_exporter::Timeout                         $streaming_timeout     = '1m',
  Atlas_exporter::Timeout                         $timeout               = '1m',
  Boolean                                         $tls_enabled           = false,
  Stdlib::Port                                    $port                  = 9400,
  Integer                                         $worker_count          = 8,
  Hash[Atlas_exporter::Histogram, Array[Float]]   $histogram_buckets     = {},
  Optional[Stdlib::Unixpath]                      $tls_cert_file         = undef,
  Optional[Stdlib::Unixpath]                      $tls_key_file          = undef,
) {
  if $tls_enabled and  ($tls_cert_file == undef or $tls_key_file == undef) {
    fail('tls_cert_file and tls_key_file must be provided when tls_enabled is true')
  }
  # Ubuntu Packages available from
  # https://github.com/icann-dns/prometheus-atlas-exporter-deb/releases
  # Debian packages available from
  # https://apt.wikimedia.org/wikimedia/pool/main/p/prometheus-atlas-exporter/
  stdlib::ensure_packages('prometheus-atlas-exporter')

  file { $config_file.dirname():
    ensure => directory,
  }

  $config = {
    'measurements' => $atlas_measurements.map |$id, $timeout| {
      { 'id' => $id, 'timeout' => $timeout }
    },
    'filter_invalid_results' => $filter_invalid,
    'histogram_buckets' => Hash(
      $histogram_buckets.map |$type, $buckets| {
        [$type, { 'rtt' => $buckets }]
      }
    ),
  }
  $arguments = {
    'cache.cleanup' => $cache_cleanup,
    'cache.ttl' => $cache_ttl,
    'config.file' => $config_file,
    'log.level' => $log_level,
    'metrics.go' => $metrics_go,
    'metrics.process' => $metrics_process,
    'profiling' => $profiling,
    'streaming' => $streaming,
    'streaming.buffer-size' => $streaming_buffer_size,
    'streaming.timeout' => $streaming_timeout,
    'timeout' => $timeout,
    'tls.enabled' => $tls_enabled,
    'tls.cert-file' => $tls_cert_file,
    'tls.key-file' => $tls_key_file,
    'web.listen-address' => ":${port}",
    'worker.count' => $worker_count,
  }.map |$key, $value| { "-${key}=${value}" }.join(' ')

  file {
    default:
      ensure => 'file',
      owner  => 'prometheus',
      notify => Service['prometheus-atlas-exporter'];
    '/etc/default/prometheus-atlas-exporter':
      content => "OPTS='${arguments}'\n";
    $config_file:
      content => stdlib::to_yaml($config);
  }

  service { 'prometheus-atlas-exporter':
    ensure  => stdlib::ensure($enable, 'service'),
    require => Package['prometheus-atlas-exporter'],
  }
}
