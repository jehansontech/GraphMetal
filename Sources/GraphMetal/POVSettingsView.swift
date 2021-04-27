//
//  POVSettingsView.swift
//  ArcWorld
//
//  Created by Jim Hanson on 3/18/21.
//

import SwiftUI
import UIStuffForSwift

struct POVSettingsView: View {

    @EnvironmentObject var povController: POVController

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .center, spacing: 10) {

            Text("POV")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {

                Button(action: resetToDefault) {
                    Text("Go to default")
                        .foregroundColor(UIConstants.controlColor)
                }
                .padding(UIConstants.buttonPadding)

                Button(action: setMark) {
                    Text("Mark")
                        .foregroundColor(UIConstants.controlColor)
                }
                .padding(UIConstants.buttonPadding)

                Button(action: resetToMark) {
                    Text("Go to mark")
                        .foregroundColor(povController.markIsSet
                                            ? UIConstants.controlColor : UIConstants.darkGray)
                }
                .padding(UIConstants.buttonPadding)
                .disabled(!povController.markIsSet)

            }
        }
    }
    
    func resetToDefault() {
        povController.goToDefaultPOV()
        presentationMode.wrappedValue.dismiss()
    }

    func setMark() {
        povController.markPOV()
        presentationMode.wrappedValue.dismiss()
    }
    
    func resetToMark() {
        povController.goToMarkedPOV()
        presentationMode.wrappedValue.dismiss()
    }
    
}

