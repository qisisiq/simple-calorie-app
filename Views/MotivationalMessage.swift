//
//  MotivationalMessage.swift
//  simple calorie app
//
//  Created by luella on 10/31/24.
//

import SwiftUI

struct MotivationalMessage: View {
    private let messages = [
        "wait until you're really hungry and then eat until you're really full",
        "stop thinking about food go do something else",
        "eating too many carbs will give you a yeast infection",
        "you can eat at a 40% calorie deficit and still maintain muscle mass if you eat 2.2g of protein per kg lean body mass",
        "eat soup",
        "take your supplements"
    ]
    
    @State private var currentMessageIndex = 0
    
    var body: some View {
        Text(messages[currentMessageIndex])
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .onTapGesture {
                withAnimation {
                    currentMessageIndex = (currentMessageIndex + 1) % messages.count
                }
            }
    }
}
