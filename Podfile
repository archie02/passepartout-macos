source 'https://github.com/cocoapods/specs.git'
platform :osx, '10.12'
use_frameworks!

load 'Podfile.include'

$tunnelkit_name = 'TunnelKit'
$tunnelkit_specs = ['Protocols/OpenVPN', 'Extra/LZO']

def shared_pods
    pod_version $tunnelkit_name, $tunnelkit_specs, '~> 2.1.0'
    #pod_git $tunnelkit_name, $tunnelkit_specs, 'd815f52'
    #pod_path $tunnelkit_name, $tunnelkit_specs, '..'
    pod 'SSZipArchive'

    for spec in ['InApp', 'Misc', 'Persistence', 'Reviewer'] do
        pod "Convenience/#{spec}", :git => 'https://github.com/keeshux/convenience', :commit => 'b990a8c'
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
