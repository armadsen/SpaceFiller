//
//  ViewController.swift
//  SpaceFiller
//
//  Created by Andrew R Madsen on 9/6/17.
//  Copyright © 2017 Open Reel Software. All rights reserved.
//

import UIKit
import Security

func freeSpaceOnDeviceInBytes() throws -> Int64 {
	let fm = FileManager.default
	let attrs = try fm.attributesOfFileSystem(forPath: "/")
	return (attrs[FileAttributeKey.systemFreeSize]) as? Int64 ?? 0
}

extension Data {
	static func randomData(numberOfBytes: Int) -> Data {
		var result = Data(count: numberOfBytes)
		result.withUnsafeMutableBytes { (ptr: UnsafeMutablePointer<UInt8>) -> Void in
			_ = SecRandomCopyBytes(kSecRandomDefault, numberOfBytes, ptr)
		}
		return result
	}
}

class ViewController: UIViewController, UITextFieldDelegate {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		updateViews()
	}
	
	@IBAction func fillSpace(_ sender: Any) {
		
		spaceToLeaveField.endEditing(true)
		
		guard let spaceToLeaveString = spaceToLeaveField.text,
			let spaceToLeave = Double(spaceToLeaveString),
			let freeSpace = try? freeSpaceOnDeviceInBytes() else {
				return
		}
		let factor: Double = unitSelector.selectedSegmentIndex == 0 ? 1e6 : 1e9
		let spaceToLeaveInBytes = Int64(spaceToLeave * factor)
		guard spaceToLeaveInBytes < freeSpace else { return }
		spaceToFill = freeSpace - spaceToLeaveInBytes
		dataWritten = 0
		do {
			let fm = FileManager.default
			if !fm.fileExists(atPath: dataFileURL.path) {
				fm.createFile(atPath: dataFileURL.path, contents: nil, attributes: nil)
			}
			fileHandle = try FileHandle(forWritingTo: dataFileURL)
			fileHandle.seekToEndOfFile()
			fileHandle.writeabilityHandler = { fileHandle in
				let spaceLeft = self.spaceToFill - self.dataWritten
				if spaceLeft == 0 {
					fileHandle.synchronizeFile()
					fileHandle.writeabilityHandler = nil
					self.fileHandle = nil
					DispatchQueue.main.async { self.updateViews() }
					return
				}
				
				let numBytesToWrite = min(spaceLeft, Int64(100e6))
				let randomData = Data.randomData(numberOfBytes: Int(numBytesToWrite))
				fileHandle.write(randomData)
				self.dataWritten += numBytesToWrite
			}
		} catch {
			NSLog("Error opening file handle: \(error)")
		}
	}
	
	@IBAction func cleanUp(_ sender: Any) {
		let fm = FileManager.default
		if fm.fileExists(atPath: dataFileURL.path, isDirectory: nil) {
			try? fm.removeItem(at: dataFileURL)
		}
		updateViews()
	}
	// MARK: UITextFieldDelegate
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		textField.resignFirstResponder()
	}
	
	// MARK: Private
	
	private func updateViews() {
		guard isViewLoaded else { return }
		do {
			availableSpaceLabel.text = byteFormatter.string(fromByteCount: try freeSpaceOnDeviceInBytes())
		} catch {
			NSLog("Error getting free space: \(error)")
		}
		updateProgressView()
	}
	
	private func updateProgressView() {
		guard fileHandle != nil else {
			progressBar.progress = 0
			progressBar.isHidden = true
			return
		}
		progressBar.isHidden = false
		progressBar.progress = Float(dataWritten) / Float(spaceToFill)
	}
	
	private lazy var byteFormatter: ByteCountFormatter = {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		formatter.zeroPadsFractionDigits = true
		return formatter
	}()
	
	private lazy var dataFileURL: URL = {
		let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
		return URL(fileURLWithPath: documents).appendingPathComponent("SpaceFiller")
	}()
	
	// MARK: Properties
	
	private var dataWritten = Int64(0) {
		didSet {
			DispatchQueue.main.async(execute: self.updateProgressView)
		}
	}
	private var spaceToFill = Int64(0) {
		didSet {
			DispatchQueue.main.async(execute: self.updateProgressView)
		}
	}
	private var fileHandle: FileHandle! {
		didSet {
			if fileHandle == nil {
				dataWritten = 0
				spaceToFill = 0
				dispatchPrecondition(condition: <#T##DispatchPredicate#>)
			}
		}
	}
	
	@IBOutlet weak var availableSpaceLabel: UILabel!
	@IBOutlet weak var spaceToLeaveField: UITextField!
	@IBOutlet weak var progressBar: UIProgressView!
	@IBOutlet weak var unitSelector: UISegmentedControl!
}

