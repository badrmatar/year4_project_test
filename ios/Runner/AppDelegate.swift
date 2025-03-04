import Flutter
import UIKit
import GoogleMaps
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private var methodChannel: FlutterMethodChannel?
  private var backgroundLocationTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GMSServices.provideAPIKey("AIzaSyBffijFTKZIwz_Psp8FpXeXhyWj23G7VWo")

    
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(
      name: "com.duorun.location/background",
      binaryMessenger: controller.binaryMessenger
    )

    
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "startBackgroundLocationUpdates":
        self.setupBackgroundLocationCapabilities()
        result(true)
      case "stopBackgroundLocationUpdates":
        self.stopBackgroundLocationUpdates()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    
    setupBackgroundLocationCapabilities()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupBackgroundLocationCapabilities() {
    
    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self

      
      locationManager?.allowsBackgroundLocationUpdates = true
      locationManager?.pausesLocationUpdatesAutomatically = false

      
      locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation

      
      locationManager?.activityType = .fitness

      
      locationManager?.showsBackgroundLocationIndicator = true

      
      locationManager?.startUpdatingLocation()

      
      locationManager?.startMonitoringSignificantLocationChanges()
    }

    print("Background location capabilities set up")
  }

  private func stopBackgroundLocationUpdates() {
    locationManager?.stopUpdatingLocation()
    locationManager?.stopMonitoringSignificantLocationChanges()
    print("Background location updates stopped")
  }

  
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    
    backgroundLocationTask = UIApplication.shared.beginBackgroundTask { [weak self] in
      guard let self = self else { return }
      if self.backgroundLocationTask != .invalid {
        UIApplication.shared.endBackgroundTask(self.backgroundLocationTask)
        self.backgroundLocationTask = .invalid
      }
    }

    
    if locationManager?.locationServicesEnabled == true {
      completionHandler(.newData)
    } else {
      completionHandler(.noData)
    }
  }

  

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    
    guard let location = locations.last else { return }

    
    let howRecent = location.timestamp.timeIntervalSinceNow
    if abs(howRecent) < 5.0 {
      
      let coordinate = location.coordinate
      let accuracy = location.horizontalAccuracy

      print("Location update from iOS native: \(coordinate.latitude), \(coordinate.longitude), accuracy: \(accuracy)")

      
      if let channel = methodChannel {
        let locationData: [String: Any] = [
          "latitude": coordinate.latitude,
          "longitude": coordinate.longitude,
          "accuracy": accuracy,
          "timestamp": location.timestamp.timeIntervalSince1970 * 1000, 
          "altitude": location.altitude,
          "speed": location.speed >= 0 ? location.speed : 0, 
          "speedAccuracy": location.speedAccuracy >= 0 ? location.speedAccuracy : 0,
        ]

        channel.invokeMethod("locationUpdate", arguments: locationData)
      }
    }

    
    if backgroundLocationTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundLocationTask)
      backgroundLocationTask = .invalid
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location manager failed with error: \(error.localizedDescription)")

    
    if let channel = methodChannel {
      channel.invokeMethod("locationError", arguments: ["message": error.localizedDescription])
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    var status = "unknown"

    if #available(iOS 14.0, *) {
      switch manager.authorizationStatus {
      case .notDetermined:
        status = "notDetermined"
      case .restricted:
        status = "restricted"
      case .denied:
        status = "denied"
      case .authorizedAlways:
        status = "authorizedAlways"
      case .authorizedWhenInUse:
        status = "authorizedWhenInUse"
      @unknown default:
        status = "unknown"
      }
    } else {
      switch CLLocationManager.authorizationStatus() {
      case .notDetermined:
        status = "notDetermined"
      case .restricted:
        status = "restricted"
      case .denied:
        status = "denied"
      case .authorizedAlways:
        status = "authorizedAlways"
      case .authorizedWhenInUse:
        status = "authorizedWhenInUse"
      @unknown default:
        status = "unknown"
      }
    }

    
    if let channel = methodChannel {
      channel.invokeMethod("authorizationStatus", arguments: ["status": status])
    }
  }
}