import UIKit
import Mapbox

class ViewController: UIViewController, MGLMapViewDelegate {

    @IBOutlet var map: MGLMapView?

    var addedLayers = [LayerInfo]()

    let countryBaseColor = UIColor(red: 241/255, green: 163/255, blue:  64/255, alpha: 1)
    let stateBaseColor   = UIColor(red: 153/255, green: 142/255, blue: 195/255, alpha: 1)
    let selectionColor   = UIColor.red

    let worldBounds = MGLCoordinateBounds(sw: CLLocationCoordinate2D(latitude: -55, longitude: -179),
                                          ne: CLLocationCoordinate2D(latitude:  75, longitude:  179))

    struct LayerInfo: Hashable {

        enum LayerType {
            case Country
            case State
        }

        var name: String
        var type: LayerType
        var opacity: MGLStyleValue<NSNumber>

        var hashValue: Int {
            return name.hash
        }

        static func == (lhs: LayerInfo, rhs: LayerInfo) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        map?.styleURL = MGLStyle.darkStyleURL(withVersion: MGLStyleDefaultVersion)
        map?.visibleCoordinateBounds = worldBounds

        map?.isScrollEnabled = false

        map?.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    func handlePan(pan: UIPanGestureRecognizer) {
        resetMap()
        if (pan.state == .began || pan.state == .changed) {
            var addedLayerNames = Set<String>()
            for addedLayer in addedLayers {
                addedLayerNames.insert(addedLayer.name)
            }
            let features = map?.visibleFeatures(at: pan.location(in: map), styleLayerIdentifiers: addedLayerNames)
            if let feature = features?.first,
               let name    = feature.attribute(forKey: "name") as? String,
               let layer   = map?.style().layer(withIdentifier: name) as? MGLFillStyleLayer {
                layer.fillColor = MGLStyleValue(rawValue: UIColor.red)
                layer.fillOpacity = MGLStyleValue(rawValue: 1)
            }
        }
    }

    func resetMap() {
        for addedLayer in addedLayers {
            if let layer = map?.style().layer(withIdentifier: addedLayer.name) as? MGLFillStyleLayer {
                layer.fillColor = MGLStyleValue(rawValue: (addedLayer.type == .Country ? countryBaseColor : stateBaseColor))
                layer.fillOpacity = addedLayer.opacity
            }
        }
    }

    func alphaForYear(year: Int) -> Double {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateFormat = "Y"
        let thisYear = (formatter.string(from: Date()) as NSString).integerValue
        return 0.9 - (0.5 * min(1, (Double(thisYear - year) / 10)))
    }

    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        if let countrySourceURL = URL(string: "mapbox://justin.d6fe2f0a"),
           let stateSourceURL   = URL(string: "mapbox://justin.ceee0bde") {
            let countrySource = MGLVectorSource(identifier: "countries", url: countrySourceURL)
            style.add(countrySource)
            let stateSource = MGLVectorSource(identifier: "states", url: stateSourceURL)
            style.add(stateSource)
            if let visitedURL = URL(string: "http://justinmiller.io/travel/visited.json") {
                URLSession.shared.dataTask(with: visitedURL,
                                           completionHandler: { [unowned self] (data, response, error) in
                    typealias JSON = Dictionary<String, AnyObject>
                    if let validData = data,
                       let visited   = try? JSONSerialization.jsonObject(with: validData, options: []) as? JSON,
                       let countries = visited?["countries"] as? [JSON],
                       let states    = visited?["states"] as? [JSON],
                       let borders   = self.map?.style().layer(withIdentifier: "admin-3-4-boundaries-bg") {
                        for country in countries {
                            let name = country["name"] as! String
                            let year = country["last"] as! Int
                            let layer = MGLFillStyleLayer(identifier: name, source: countrySource)
                            layer.sourceLayerIdentifier = "countries"
                            layer.predicate = NSPredicate(format: "name == %@", name)
                            layer.fillColor = MGLStyleValue(rawValue: self.countryBaseColor)
                            layer.fillOpacity = MGLStyleValue(rawValue: NSNumber(value: self.alphaForYear(year: year)))
                            DispatchQueue.main.async {
                                style.insert(layer, below: borders)
                                self.addedLayers.append(LayerInfo(name: name,
                                                                  type: .Country,
                                                                  opacity: layer.fillOpacity))
                            }
                        }
                        for state in states {
                            let name = state["name"] as! String
                            let year = state["last"] as! Int
                            let layer = MGLFillStyleLayer(identifier: name, source: stateSource)
                            layer.sourceLayerIdentifier = "states"
                            layer.predicate = NSPredicate(format: "gn_name == %@", name)
                            layer.fillColor = MGLStyleValue(rawValue: self.stateBaseColor)
                            layer.fillOpacity = MGLStyleValue(rawValue: NSNumber(value: self.alphaForYear(year: year)))
                            DispatchQueue.main.async {
                                style.insert(layer, below: borders)
                                self.addedLayers.append(LayerInfo(name: name,
                                                                  type: .State,
                                                                  opacity: layer.fillOpacity))
                            }
                        }
                    }
                }).resume()
            }
        }
    }

}
