Pod::Spec.new do |s|
  s.name             = 'soundwave_core'
  s.version          = '0.0.1'
  s.summary          = 'SoundWave native core SDK (placeholder)'
  s.description      = <<-DESC
Core SDK for SoundWave native processing. This is a placeholder pending full PCM/FFT migration.
  DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../../LICENSE' }
  s.author           = { 'SoundWave' => 'dev@soundwave' }
  s.source           = { :path => '.' }
  s.source_files     = [
    'Sources/SoundwaveCore/**/*.{swift,h,c}',
    '../../native/core/third_party/kissfft/kiss_fft.c',
    '../../native/core/third_party/kissfft/kiss_fftr.c',
    '../../native/core/third_party/kissfft/kiss_fft.h',
    '../../native/core/third_party/kissfft/kiss_fftr.h',
    '../../native/core/third_party/kissfft/_kiss_fft_guts.h'
  ]
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../../native/core/third_party/kissfft"',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'KISS_FFT_FLOAT=1'
  }
  s.module_name      = 'SoundwaveCore'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
end
