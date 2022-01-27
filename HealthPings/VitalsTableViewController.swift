//
//  VitalsTableViewController.swift
//  HealthPings
//
//  Created by Aleksey Novikov on 25.01.2022.
//

import CoreBluetooth
import CryptoSwift
import UIKit

class VitalsTableViewController: UITableViewController {
    @IBOutlet var activityIndicators: [UIActivityIndicatorView]!
    
    @IBOutlet var unitLabels: [UILabel]!
    
    @IBOutlet weak var systolicLabel: UILabel!
    @IBOutlet weak var diastolicLabel: UILabel!
    @IBOutlet weak var currentTemperatureLabel: UILabel!
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var saturationLabel: UILabel!
    
    var centralManager: CBCentralManager!
    
    var activityTrackerPeripheral: CBPeripheral!
    var bloodPressureMonitorPeripheral: CBPeripheral!
    var thermometerPeripheral: CBPeripheral!
    
    var isAuthorized: Bool = false
    var isSearching: Bool = false
    
    let xmarkImage = UIImage(systemName: "xmark")
    let magnifyingglassImage = UIImage(systemName: "magnifyingglass")
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    @IBAction func startSearch(_ sender: UIBarButtonItem) {
        guard centralManager.state == .poweredOn else {
            showAlertBTOff()
            return
        }
        if isSearching == false
        {
            centralManager.scanForPeripherals(withServices: [healthThermometerServiceCBUUID, bloodPressureServiceCBUUID, anhuiHuami1InformationServiceCBUUID], options: nil)
            for indicator in activityIndicators {
                indicator.startAnimating()
            }
            isSearching = true
            sender.image = xmarkImage
        } else {
            centralManager.stopScan()
            for indicator in activityIndicators {
                indicator.stopAnimating()
            }
            isSearching = false
            sender.image = magnifyingglassImage
        }
    }
    
    func onHeartRateReceived(_ heartRate: Int) {
        heartRateLabel.text = String(heartRate)
    }
    
    func onBloodPressureReceived(_ bloodPressure: BloodPressure) {
        systolicLabel.text = String(bloodPressure.systolic)
        diastolicLabel.text = String(bloodPressure.diastolic)
        for unitLabel in unitLabels {
            unitLabel.text = bloodPressure.unit
        }
    }
    
    func onSaturationReceived(_ saturation: Int) {
        // TODO: On saturation received
        saturationLabel.text = String(saturation)
    }
    
    func onTemperatureReceived(_ temperature: Float) {
        currentTemperatureLabel.text = String(temperature)
    }
    
    private func showAlertBTOff() {
        let alert = UIAlertController(title: "Нет доступа к Bluetooth", message: "Пожалуйста, проверьте состояние Bluetooth", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "ОК", style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}
