//
//  Convert.swift
//  HealthPings
//
//  Created by Aleksey Novikov on 27.01.2022.
//

import CoreBluetooth
import Foundation

enum unit: String {
    case mmHg = "мм. рт. ст."
    case kPa = "кПа"
}

struct MeasurementStatus {
    var bodyMovementDetectionFlag: Bool
    let cuffFitDetectionFlag: Bool
    let irregularPulseDetectionFlag: Bool
    let pulserRateExceedsUpperLimit: Bool
    let pulseRateIsLessThanLowerLimit: Bool
    let measurementPositionDetectionFlag: Bool
}

struct BloodPressure {
    let systolic: Float
    let diastolic: Float
    let arterial: Float
    let unit: String
    let timeStamp: Date?
    let pulseRate: Float?
    let userID: UInt8?
    let status: MeasurementStatus?
}

func bloodPressure(from characteristic:CBCharacteristic) -> BloodPressure! {
    guard let characteristicData = characteristic.value else { return nil }
    var byteArray = [UInt8](characteristicData)
    let flags = byteArray.removeFirst()
    var un: String
    var d: Float
    var measureTime:Date!
    var pulseRate: Float!
    var userID: UInt8!
    var status: MeasurementStatus!
    if flags & 0x01 == 0 {
        un = unit.mmHg.rawValue
        d = 1
    } else {
        un = unit.kPa.rawValue
        d = 1000
    }
    let systolic = extractSFloat(values: byteArray, startingIndex: 0) * d
    let diastolic = extractSFloat(values: byteArray, startingIndex: 2) * d
    let arterial = extractSFloat(values: byteArray, startingIndex: 4) * d
    byteArray.removeFirst(6)
    if flags & 0x02 == 2 {
        var dateComponents = DateComponents()
        dateComponents.year = Int([byteArray[0], byteArray[1]].withUnsafeBytes { $0.load(as: UInt16.self) })
        dateComponents.month = Int(byteArray[2])
        dateComponents.day = Int(byteArray[3])
        dateComponents.timeZone = TimeZone.current
        dateComponents.hour = Int(byteArray[4])
        dateComponents.minute = Int(byteArray[5])
        dateComponents.second = Int(byteArray[6])
        let userCalendar = Calendar(identifier: .gregorian) // since the components above (like year 1980) are for Gregorian
        measureTime = userCalendar.date(from: dateComponents)!
    }
    byteArray.removeFirst(7)
    if flags & 0x04 == 4 {
        pulseRate = extractSFloat(values: byteArray, startingIndex: 0)
        byteArray.removeFirst(2)
    }
    if flags & 0x08 == 8 {
        userID = byteArray.removeFirst()
    }
    if flags & 0x10 == 16 {
        let measurementStatus = byteArray.removeFirst()
        status = MeasurementStatus(
            bodyMovementDetectionFlag: measurementStatus & 0x01 == 1,
            cuffFitDetectionFlag: measurementStatus & 0x02 == 2,
            irregularPulseDetectionFlag: measurementStatus & 0x04 == 4,
            pulserRateExceedsUpperLimit: measurementStatus & 0x08 == 8,
            pulseRateIsLessThanLowerLimit: measurementStatus & 0x10 == 16,
            measurementPositionDetectionFlag: measurementStatus & 0x20 == 32
        )
    }
    
    return BloodPressure(
        systolic: systolic,
        diastolic: diastolic,
        arterial: arterial,
        unit: un,
        timeStamp: measureTime,
        pulseRate: pulseRate,
        userID: userID,
        status: status
    )
}

func heartRate(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)
    
    let firstBitValue = byteArray[0] & 0x01
    if firstBitValue == 0 {
        // Heart Rate Value Format is in the 2nd byte
        return Int(byteArray[1])
    } else {
        // Heart Rate Value Format is in the 2nd and 3rd bytes
        return (Int(byteArray[1]) << 8) + Int(byteArray[2])
    }
}

func saturationMeasurement(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)
    return Int(byteArray[1])
    // TODO: Saturation measurement
}

func temperatureMeasurement(from characteristic: CBCharacteristic) -> Float {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)
    let uint16 = [byteArray[1], byteArray[2]].withUnsafeBytes { $0.load(as: UInt16.self) }
    return (Float(uint16) / Float(10))
}

func floatFromTwosComplementUInt16(_ value: UInt16, havingBitsInValueIncludingSign bitsInValueIncludingSign: Int) -> Float {
    // calculate a signed float from a two's complement signed value
    // represented in the lowest n ("bitsInValueIncludingSign") bits
    // of the UInt16 value
    let signMask: UInt16 = UInt16(0x1) << (bitsInValueIncludingSign - 1)
    let signMultiplier: Float = (value & signMask == 0) ? 1.0 : -1.0
    
    var valuePart = value
    if signMultiplier < 0 {
        // Undo two's complement if it's negative
        var valueMask = UInt16(1)
        for _ in 0 ..< bitsInValueIncludingSign - 2 {
            valueMask = valueMask << 1
            valueMask += 1
        }
        valuePart = ((~value) & valueMask) &+ 1
    }
    
    let floatValue = Float(valuePart) * signMultiplier
    
    return floatValue
}

func extractSFloat(values: [UInt8], startingIndex index: Int) -> Float {
    // IEEE-11073 16-bit SFLOAT -> Float
    let full = UInt16(values[index+1]) * 256 + UInt16(values[index])
    
    // Check special values defined by SFLOAT first
    if full == 0x07FF {
        return Float.nan
    } else if full == 0x800 {
        return Float.nan // This is really NRes, "Not at this Resolution"
    } else if full == 0x7FE {
        return Float.infinity
    } else if full == 0x0802 {
        return -Float.infinity // This is really negative infinity
    } else if full == 0x801 {
        return Float.nan // This is really RESERVED FOR FUTURE USE
    }
    
    // Get exponent (high 4 bits)
    let expo = (full & 0xF000) >> 12
    let expoFloat = floatFromTwosComplementUInt16(expo, havingBitsInValueIncludingSign: 4)
    
    // Get mantissa (low 12 bits)
    let mantissa = full & 0x0FFF
    let mantissaFloat = floatFromTwosComplementUInt16(mantissa, havingBitsInValueIncludingSign: 12)
    
    // Put it together
    let finalValue = mantissaFloat * pow(10.0, expoFloat)
    
    return finalValue
}
