Pod::Spec.new do |spec|

spec.name         = "Cardstream"
spec.version      = "0.0.2"
spec.summary      = "Cardstream SDK"

spec.description  = "Gateway SDK for Cardstream"

spec.homepage     = "https://github.com/MarKenn/Cardstream"

spec.license      = "GNU GPLv3"

spec.author       = { "Mark Kenneth M. Bayona" => "mkmbayona@gmail.com" }

spec.platform     = :ios, "12.0"

spec.source       = { :git => "https://github.com/MarKenn/Cardstream.git", :tag => "#{spec.version}" }

spec.source_files  = "Cardstream/**/*.{swift,h}"
#spec.exclude_files = "Classes/Exclude"

spec.public_header_files = "Cardstream/**/*.h"
# spec.public_header_files = "cardstream-ios-sdk/Classes/**/*.h"

spec.dependency "CryptoSwift", "~> 1.4.1"

spec.swift_versions = "4.2"
end
