// ContentView.swift
import SwiftUI
import WatchKit

struct WaitOption: Identifiable {
    let id: Int
    let timeText: String
    let color: Color
}

class WaitTimeManager: ObservableObject {
    @Published var isLoading = false
    @Published var selectedOption: Int?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    private var timer: Timer?
    
    private let apiURL = "https://holybellycafe.com/watch-api.php"
    private let apiKey = "5f6d8a9b3c2e1f4d7a8b9c0e1f2a3b4c"
    
    init() {
        startPolling()
    }
    
    private func startPolling() {
        // Initial fetch
        getCurrentSelection()
        
        // Set up timer for periodic updates
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.getCurrentSelection()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopPolling()
    }
    
    func updateWaitTime(optionId: Int) {
        isLoading = true
        
        guard let url = URL(string: apiURL) else {
            showError("Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let parameters = ["option_id": optionId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.showError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showError("Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self?.selectedOption = optionId
                    WKInterfaceDevice.current().play(.success)
                    self?.alertMessage = "Wait time updated successfully"
                    self?.showingAlert = true
                } else {
                    self?.showError("Server error: \(httpResponse.statusCode)")
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }.resume()
    }
    
    func getCurrentSelection() {
        guard !isLoading else { return }
        
        guard let url = URL(string: apiURL + "?action=current") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let currentOption = json["current_option_id"] as? Int else {
                return
            }
            
            DispatchQueue.main.async {
                // Only update if the selection has changed
                if self.selectedOption != currentOption {
                    self.selectedOption = currentOption
                }
            }
        }.resume()
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
        WKInterfaceDevice.current().play(.failure)
    }
}

struct ContentView: View {
    @StateObject private var waitTimeManager = WaitTimeManager()
    
    let waitOptions = [
        WaitOption(id: 1, timeText: "NO WAIT", color: .green),
        WaitOption(id: 2, timeText: "15-30 MIN", color: .yellow),
        WaitOption(id: 3, timeText: "30-45 MIN", color: .orange),
        WaitOption(id: 4, timeText: "1 HOUR", color: .red)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(waitOptions) { option in
                    Button(action: {
                        withAnimation {
                            waitTimeManager.updateWaitTime(optionId: option.id)
                        }
                    }) {
                        Text(option.timeText)
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(waitTimeManager.selectedOption == option.id ? Color.black : option.color)
                            .overlay(
                                HStack {
                                    if waitTimeManager.selectedOption == option.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .padding(.leading, 8)
                                        Spacer()
                                        Text("SELECTED")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.trailing, 8)
                                    }
                                }
                            )
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .disabled(waitTimeManager.isLoading)
                }
                
                if waitTimeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding(.horizontal, 8)
        }
        .alert(isPresented: $waitTimeManager.showingAlert) {
            Alert(
                title: Text("Update Status"),
                message: Text(waitTimeManager.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
