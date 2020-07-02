source 'https://github.com/cocoapods/specs.git'
platform :osx, '10.12'
use_frameworks!

load 'Podfile.include'

$tunnelkit_name = 'TunnelKit'
$tunnelkit_specs = ['Protocols/OpenVPN', 'Manager', 'Extra/LZO']

def shared_pods
    #pod_version $tunnelkit_name, $tunnelkit_specs, '~> 2.1.0'
    pod_git $tunnelkit_name, $tunnelkit_specs, '683617d'
    #pod_path $tunnelkit_name, $tunnelkit_specs, '..'
    pod 'SSZipArchive'

    for spec in ['InApp', 'Misc', 'Persistence', 'Reviewer', 'WebServices'] do
        pod "Convenience/#{spec}", :git => 'https://github.com/keeshux/convenience', :commit => '0b09b1e'
    end
end

target 'PassepartoutCore-macOS' do
    shared_pods
end

target 'Passepartout-macOS' do
    pod 'AppCenter'
end
target 'Passepartout-macOS-Tunnel' do
    shared_pods
end
