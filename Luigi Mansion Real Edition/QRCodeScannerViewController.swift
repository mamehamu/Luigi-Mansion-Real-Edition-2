//
//  QRcode_Scanner.swift
//  Luigi Mansion Real Edition
//
//  Created by ryu on 2024/10/04.
//

import AVFoundation
import UIKit
import CoreMotion

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    var isQRCodeDetected = false
    var qrCodeDetectedTime: Date?
    var qrCodeGoneTimer: Timer?
    var isSuctionMode = false // 吸い取りモードかどうかを管理
    
    var exterminatedCount = 0 // 退治数
    let maxExterminationCount = 5 // 退治できる最大数
    var gameTimer: Timer?
    var remainingTime = 180 // 制限時間3分（180秒）

    // 吸い込み開始ボタンをクラス全体で使えるようにプロパティとして定義
    var suctionButton: UIButton!
    
    let motionManager = CMMotionManager()
    var suctionDuration: TimeInterval = 10.0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupSuctionButton()
        startGameTimer()
        
        // 加速度センサ開始
        startAccelerometerUpdates()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    // 吸い取りモードに入るためのボタン
    func setupSuctionButton() {
        suctionButton = UIButton(frame: CGRect(x: 50, y: 50, width: 200, height: 50)) // 修正：ここで変数を代入
        suctionButton.setTitle("吸い取り開始", for: .normal)
        suctionButton.backgroundColor = .blue
        suctionButton.isHidden = true
        suctionButton.addTarget(self, action: #selector(suctionButtonTapped), for: .touchUpInside)

        view.addSubview(suctionButton)
        print("吸い取りボタンがビューに追加されました")
    }

    // 吸い取りモードに移行
    @objc func suctionButtonTapped() {
        guard isQRCodeDetected && !isSuctionMode else { return }
        isSuctionMode = true
        suctionButton.isHidden = true // ボタンを非表示にする
        
        //吸い込み時間リセット
        suctionDuration = 10.0
            
        // バックグラウンドスレッドでカメラのQRコード検出を一時停止
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning() // カメラのQRコード検出を一時停止
            print("吸い取りモードに移行しました！")
            
            // 加速度センサの反応を再スタート
            self.startAccelerometerUpdates()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.suctionDuration) {
                // 吸い込み完了後、退治数を1増やす
                self.exterminatedCount += 1
                print("退治完了！現在の退治数: \(self.exterminatedCount)")

                // 退治数がMAXかどうかを確認
                if self.exterminatedCount >= self.maxExterminationCount {
                    self.endGame(win: true)
                } else {
                    // 吸い込みモード終了
                    self.suctionCompleted()
                }
            }
        }
    }

    // 吸い込み完了処理
    func suctionCompleted() {
        print("吸い込みが完了しました！")
        
        // 吸い込みモードを終了
        isSuctionMode = false
        suctionButton.isHidden = true // ボタンを非表示に戻す
        
        // 必要な処理を追加
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning() // QRコードの検出を再開
            print("QRコード読み込みモードに戻りました")
        }
    }

    // ゲーム終了処理
    func endGame(win: Bool) {
        captureSession.stopRunning()
        gameTimer?.invalidate()
        
        if win {
            print("全てのおばけを退治しました！ゲームクリア！")
        } else {
            print("制限時間切れ！ゲームオーバー！")
        }
        
        // ゲーム終了後の画面遷移や再スタートの処理を追加
    }

    // ゲーム開始から3分のタイマー
    func startGameTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingTime -= 1
            print("残り時間: \(self.remainingTime)秒")
            
            if self.remainingTime <= 0 {
                self.endGame(win: false) // 時間切れ
            }
        }
    }
    
    // QRコード検出時の処理
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            if !isQRCodeDetected {
                isQRCodeDetected = true
                qrCodeDetectedTime = Date()
                print("QRコードが見つかりました: \(stringValue)")
                // QRコードを読み取ったら即座にボタンを表示
                DispatchQueue.main.async {
                    self.suctionButton.isHidden = false // ボタンを表示
                }
            }
        } else {
            // QRコードが見えなくなった場合
            if isQRCodeDetected {
                isQRCodeDetected = false
                qrCodeDetectedTime = nil
                
                // QRコードが見えなくなったら即座にボタン非表示
                DispatchQueue.main.async {
                    self.suctionButton.isHidden = true
                    print("QRコードが見えなくなりました。ボタンを非表示にしました。")
                }
            }
        }
    }
    
    // 加速度センサーを開始するメソッド
    func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1 // 更新間隔を設定
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (data, error) in
                guard let data = data, self.isSuctionMode else { return }
                
                // 加速度の大きさを計算
                let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
                
                // 振動の強さを閾値で判断
                if acceleration > 1.1 { // ここで閾値を調整
                    self.suctionDuration -= 0.5 // 吸い取り時間を短縮
                    if self.suctionDuration < 1.0 { // 最小時間に達したら吸い込み終了
                        self.suctionDuration = 1.0
                        print("吸い込み時間が最短に達したため、吸い込みを終了します")

                        if self.isSuctionMode {
                            self.suctionCompleted() // 強制的に吸い込みを終了
                        }
                    } else {
                        print("吸い取り時間が短縮されました: \(self.suctionDuration)秒")
                    }
                }
            }
        }
    }

    // 加速度センサーの更新を停止するメソッド
    func stopAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.stopAccelerometerUpdates()
            print("加速度センサーの更新が停止されました")
        }
    }
}
