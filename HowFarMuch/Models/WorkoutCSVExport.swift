import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Shareable CSV of a set of workouts. The file is only generated when the
/// user commits the share, not on every render.
struct WorkoutCSVExport: Transferable {
    let workouts: [WorkoutRecord]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            export.csvData()
        }
        .suggestedFileName("HowFarMuch-workouts.csv")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    func csvData() -> Data {
        var lines = ["Date,Start Time,Activity,Source,Duration (min),Distance (km),Distance (mi),Calories (kcal),Avg Heart Rate (bpm)"]
        for workout in workouts.sorted(by: { $0.start > $1.start }) {
            let fields = [
                Self.dateFormatter.string(from: workout.start),
                Self.timeFormatter.string(from: workout.start),
                workout.type.displayName,
                (workout.sourceName ?? "").replacingOccurrences(of: ",", with: ";"),
                String(format: "%.1f", workout.duration / 60),
                String(format: "%.2f", workout.distanceMeters / 1000),
                String(format: "%.2f", workout.distanceMeters / 1609.344),
                String(format: "%.0f", workout.energyKilocalories),
                workout.averageHeartRate.map { String(format: "%.0f", $0) } ?? "",
            ]
            lines.append(fields.joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }
}
