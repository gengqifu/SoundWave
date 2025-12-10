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
  s.source_files     = 'Sources/SoundwaveCore/**/*'
  s.module_name      = 'SoundwaveCore'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
end
