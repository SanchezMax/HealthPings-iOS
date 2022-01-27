//
//  Bluetooth.swift
//  HealthPings
//
//  Created by Aleksey Novikov on 25.01.2022.
//

import CoreBluetooth
import CryptoSwift
import Foundation

let healthThermometerServiceCBUUID = CBUUID(string: "0x1809")
let heartRateServiceCBUUID = CBUUID(string: "0x180D")
let bloodPressureServiceCBUUID = CBUUID(string: "0x1810")
let anhuiHuami1InformationServiceCBUUID = CBUUID(string: "0xFEE0")
let anhuiHuami2InformationServiceCBUUID = CBUUID(string: "0xFEE1")

let intermediateTemperatureCharacteristicCBUUID = CBUUID(string: "2A1E")
let bloodPressureMeasurementCharacteristicCBUUID = CBUUID(string: "0x2A35")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let heartRateControlPointCharacteristicCBUUID = CBUUID(string: "2A39")
let authCharacteristicCBUUID = CBUUID(string: "00000009-0000-3512-2118-0009AF100700")

let key: Array<UInt8> = [0x40, 0xb4, 0x4b, 0xe2, 0xf1, 0x08, 0xea, 0x02, 0xaa, 0x1a, 0x01, 0xad, 0x76, 0x95, 0xa1, 0x0e]

extension VitalsTableViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        switch peripheral.name {
        case "A&D_UA-651BLE_91920A":
            activityIndicators[0].stopAnimating()
            activityIndicators[1].stopAnimating()
            self.bloodPressureMonitorPeripheral = peripheral
            self.bloodPressureMonitorPeripheral.delegate = self
            self.centralManager.connect(bloodPressureMonitorPeripheral, options: nil)
        case "WT50: ":
            activityIndicators[2].stopAnimating()
            self.thermometerPeripheral = peripheral
            self.thermometerPeripheral.delegate = self
            self.centralManager.connect(thermometerPeripheral, options: nil)
        case "Mi Band 3":
            activityIndicators[3].stopAnimating()
            self.activityTrackerPeripheral = peripheral
            self.activityTrackerPeripheral.delegate = self
            self.centralManager.connect(activityTrackerPeripheral, options: nil)
        default:
            break
        }
        
        guard activityTrackerPeripheral == nil || bloodPressureMonitorPeripheral == nil || thermometerPeripheral == nil else {
            self.centralManager.stopScan()
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        switch peripheral.name {
        case "A&D_UA-651BLE_91920A":
            peripheral.discoverServices([bloodPressureServiceCBUUID])
        case "WT50: ":
            peripheral.discoverServices([healthThermometerServiceCBUUID])
        case "Mi Band 3":
            peripheral.discoverServices([anhuiHuami2InformationServiceCBUUID])
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        switch peripheral.name {
        case "A&D_UA-651BLE_91920A":
            activityIndicators[0].startAnimating()
            activityIndicators[1].startAnimating()
        case "WT50: ":
            activityIndicators[2].startAnimating()
        case "Mi Band 3":
            activityIndicators[3].startAnimating()
            isAuthorized = false
        default:
            break
        }
        central.scanForPeripherals(withServices: [healthThermometerServiceCBUUID, bloodPressureServiceCBUUID, anhuiHuami1InformationServiceCBUUID], options: nil)
    }
}

extension VitalsTableViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            switch service.uuid {
            case anhuiHuami2InformationServiceCBUUID:
                peripheral.discoverCharacteristics([authCharacteristicCBUUID], for: service)
            case bloodPressureServiceCBUUID:
                peripheral.discoverCharacteristics([bloodPressureMeasurementCharacteristicCBUUID], for: service)
            case healthThermometerServiceCBUUID:
                peripheral.discoverCharacteristics([intermediateTemperatureCharacteristicCBUUID], for: service)
            case heartRateServiceCBUUID:
                peripheral.discoverCharacteristics([heartRateControlPointCharacteristicCBUUID, heartRateMeasurementCharacteristicCBUUID], for: service)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case authCharacteristicCBUUID:
                guard isAuthorized == false else {return}
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.writeValue(Data([0x01, 0x00]), for: characteristic, type: .withoutResponse)
            case bloodPressureMeasurementCharacteristicCBUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case heartRateControlPointCharacteristicCBUUID:
                peripheral.writeValue(Data([0x15, 0x02, 0x00]), for: characteristic, type: .withResponse)
                peripheral.writeValue(Data([0x15, 0x01, 0x00]), for: characteristic, type: .withResponse)
                peripheral.writeValue(Data([0x15, 0x01, 0x01]), for: characteristic, type: .withResponse)
                _ = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
                    peripheral.writeValue(Data([0x16]), for: characteristic, type: .withResponse)
                }
            case heartRateMeasurementCharacteristicCBUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case intermediateTemperatureCharacteristicCBUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
            
            //            if characteristic.properties.contains(.read) {
            //                print("\(characteristic.uuid): properties contains .read")
            //            }
            //            if characteristic.properties.contains(.notify) {
            //                print("\(characteristic.uuid): properties contains .notify")
            //            }
            //            if characteristic.properties.contains(.notifyEncryptionRequired) {
            //                print("\(characteristic.uuid): properties contains .notifyEncryptionRequired")
            //            }
            //            if characteristic.properties.contains(.write) {
            //                print("\(characteristic.uuid): properties contains .write")
            //            }
            //            if characteristic.properties.contains(.writeWithoutResponse) {
            //                print("\(characteristic.uuid): properties contains .writeWithoutResponse")
            //            }
            //            if characteristic.properties.contains(.indicate) {
            //                print("\(characteristic.uuid): properties contains .indicate")
            //            }
            //            if characteristic.properties.contains(.indicateEncryptionRequired) {
            //                print("\(characteristic.uuid): properties contains .indicateEncryptionRequired")
            //            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case authCharacteristicCBUUID:
            switch characteristic.value {
            case Data([16, 1, 4]):
                peripheral.writeValue(Data([0x02, 0x00, 0x02]), for: characteristic, type: .withoutResponse)
            case Data([16, 3, 1]):
                isAuthorized = true
                peripheral.setNotifyValue(false, for: characteristic)
                peripheral.discoverServices([anhuiHuami1InformationServiceCBUUID, heartRateServiceCBUUID])
            case .none:
                break
            case .some(_):
                var byteArray:[UInt8] = [UInt8](characteristic.value!)
                if byteArray.dropLast(16) == [16, 2, 1] {
                    byteArray.removeFirst(3)
                    let encrypted: Array<UInt8> = try! AES(key: key, blockMode: ECB(), padding: .noPadding).encrypt(byteArray)
                    peripheral.writeValue(Data([0x03, 0x00] + encrypted), for: characteristic, type: .withoutResponse)
                }
            }
        case bloodPressureMeasurementCharacteristicCBUUID:
            onBloodPressureReceived(bloodPressure(from: characteristic))
        case heartRateMeasurementCharacteristicCBUUID:
            onHeartRateReceived(heartRate(from: characteristic))
        case intermediateTemperatureCharacteristicCBUUID:
            onTemperatureReceived(temperatureMeasurement(from: characteristic))
        default:
            break
        }
    }
}
