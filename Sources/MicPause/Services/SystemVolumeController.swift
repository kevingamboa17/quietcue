import AudioToolbox
import CoreAudio
import Foundation

struct SystemVolumeSnapshot: Equatable, Sendable {
    let volume: Float
    let isMuted: Bool
}

final class SystemVolumeController: @unchecked Sendable {
    func snapshot() -> SystemVolumeSnapshot? {
        guard let deviceID = defaultOutputDeviceID(),
              let volume = getVolume(deviceID: deviceID) else {
            return nil
        }
        return SystemVolumeSnapshot(
            volume: volume,
            isMuted: getMute(deviceID: deviceID) ?? false
        )
    }

    @discardableResult
    func setVolume(_ volume: Float) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        return setVolume(deviceID: deviceID, volume: min(1, max(0, volume)))
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        return setMute(deviceID: deviceID, muted: muted)
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func volumeElements(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        elements(deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            ?? elements(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar)
            ?? []
    }

    private func muteElements(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        elements(deviceID: deviceID, selector: kAudioDevicePropertyMute) ?? []
    }

    private func elements(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> [AudioObjectPropertyElement]? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &address) {
            return [kAudioObjectPropertyElementMain]
        }

        var found: [AudioObjectPropertyElement] = []
        for element: AudioObjectPropertyElement in 1...2 {
            address.mElement = element
            if AudioObjectHasProperty(deviceID, &address) {
                found.append(element)
            }
        }
        return found.isEmpty ? nil : found
    }

    private func getVolume(deviceID: AudioDeviceID) -> Float? {
        let virtualAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var address = virtualAddress
        if AudioObjectHasProperty(deviceID, &address),
           let value = getFloat(deviceID: deviceID, address: &address) {
            return value
        }

        let elements = volumeElements(deviceID: deviceID)
        guard !elements.isEmpty else { return nil }
        var total: Float32 = 0
        var count: Float32 = 0
        for element in elements {
            address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if let value = getFloat(deviceID: deviceID, address: &address) {
                total += value
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return total / count
    }

    private func setVolume(deviceID: AudioDeviceID, volume: Float) -> Bool {
        var virtualAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &virtualAddress) {
            return setFloat(deviceID: deviceID, address: &virtualAddress, volume)
        }

        let elements = volumeElements(deviceID: deviceID)
        guard !elements.isEmpty else { return false }
        var succeeded = false
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if setFloat(deviceID: deviceID, address: &address, volume) {
                succeeded = true
            }
        }
        return succeeded
    }

    private func getMute(deviceID: AudioDeviceID) -> Bool? {
        let elements = muteElements(deviceID: deviceID)
        guard let element = elements.first else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard let value = getUInt32(deviceID: deviceID, address: &address) else {
            return nil
        }
        return value != 0
    }

    private func setMute(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        let elements = muteElements(deviceID: deviceID)
        guard !elements.isEmpty else { return false }
        var succeeded = false
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if setUInt32(deviceID: deviceID, address: &address, muted ? 1 : 0) {
                succeeded = true
            }
        }
        return succeeded
    }

    private func getFloat(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> Float32? {
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func getUInt32(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> UInt32? {
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func setFloat(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress,
        _ value: Float
    ) -> Bool {
        guard isSettable(deviceID: deviceID, address: &address) else { return false }
        var scalar = Float32(value)
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar) == noErr
    }

    private func setUInt32(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress,
        _ value: UInt32
    ) -> Bool {
        guard isSettable(deviceID: deviceID, address: &address) else { return false }
        var scalar = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar) == noErr
    }

    private func isSettable(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(deviceID, &address, &settable)
        return status == noErr && settable.boolValue
    }
}
