Pod::Spec.new do |s|
  s.name         = "CBModel"
  s.version      =  "1.0.0"
  s.summary      = "对于FMDB的封装,针对Model层的直接存储，包含JSON<->Modle转换."
  s.homepage     = "https://github.com/cbangchen/CBModel"
  s.license      = 'MIT'
  s.author       = { "陈超邦" => "http://cbang.info" }
  s.platform     = :ios, "7.0"
  s.ios.deployment_target = "7.0"
  s.source       = { :git => "https://github.com/cbangchen/CBModel.git", :tag => s.version }
  s.source_files  = 'CBModel/CBModel/*.{h,m}'
  s.dependency "FMDB"
  s.requires_arc = true
end