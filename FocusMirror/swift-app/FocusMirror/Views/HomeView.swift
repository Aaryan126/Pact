import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [UUID]
    @State private var cameraMessage: String?

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start session")
                        .font(.largeTitle.weight(.semibold))
                    Text("FocusMirror observes silently and summarizes screen focus after you end the session.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Length")
                        .font(.headline)
                    Picker("Length", selection: $model.selectedLength) {
                        ForEach(SessionLength.allCases) { length in
                            Text(length.label).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 340)
                }

                Button {
                    Task {
                        let status = await CameraPermission.request()
                        guard status == .authorized else {
                            cameraMessage = "Camera permission is required before starting."
                            return
                        }
                        model.startSession()
                    }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(width: 180)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let error = model.engineError ?? cameraMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HistoryView(path: $path)
                .frame(width: 360)
        }
        .navigationTitle("FocusMirror")
    }
}
