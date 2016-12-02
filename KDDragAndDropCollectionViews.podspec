Pod::Spec.new do |s|
  s.name             = 'KDDragAndDropCollectionViews'
  s.version          = '0.1.0'
  s.summary          = 'Drag and Drop Views'
  s.description      = <<-DESC
This is an implementation of Dragging and Dropping data across multiple UICollectionViews.
                       DESC

  s.homepage         = 'https://github.com/pmarnik/KDDragAndDropCollectionViews'
  s.license          = { :type => 'MIT', :file => 'LICENCE.md' }
  s.authors          = { 'Michael Michailidis' => '', 'Piotr Marnik' => 'piotr.marnik@gmail.com' }
  s.source           = { :git => 'https://github.com/pmarnik/KDDragAndDropCollectionViews.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'KDDragAndDropCollectionViews/KDDragAndDrop*.swift'
  
  # s.resource_bundles = {
  #   'KDDragAndDropCollectionView' => ['KDDragAndDropCollectionViews/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
