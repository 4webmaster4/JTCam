// ContentView.swift
import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        CameraViewControllerWrapper()
            .edgesIgnoringSafeArea(.all)
    }
}

struct CameraViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Update the view controller if needed
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
