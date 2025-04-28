platform :ios, '14.0'

# 添加post_install钩子来修复沙盒权限问题
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # 关闭沙盒限制
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
      config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
    end
  end
end

target 'pay_nfc' do
  use_frameworks! :linkage => :static

  # Pods for pay_nfc
  pod 'GoogleSignIn'
  # pod 'JWTDecode'
  # pod 'SuiKit'


  target 'pay_nfcTests' do
    inherit! :search_paths
    # Pods for testing
  end

end
