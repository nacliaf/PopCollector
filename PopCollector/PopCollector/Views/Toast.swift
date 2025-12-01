//
//  Toast.swift
//  PopCollector
//
//  Beautiful iOS-style toast notifications
//

import SwiftUI

struct Toast: View {
    let message: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .font(.title3)
            
            Text(message)
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    static func show(message: String, systemImage: String = "checkmark.circle.fill") {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let toast = Toast(message: message, systemImage: systemImage)
        let host = UIHostingController(rootView: toast)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        
        window.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            host.view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
            host.view.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
        
        host.view.alpha = 0
        
        UIView.animate(withDuration: 0.3, animations: {
            host.view.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.animate(withDuration: 0.3, animations: {
                    host.view.alpha = 0
                }) { _ in
                    host.view.removeFromSuperview()
                }
            }
        }
    }
}

