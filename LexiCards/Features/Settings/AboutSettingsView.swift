import SwiftUI

/// What LexiCards is, where it came from, and what it costs.
///
/// The same four facts the system panel showed, in the app's own hand: the mark,
/// the version, one sentence, and the two places worth going. The copyright and
/// licence keep the smallest type, as they do in every About on the system —
/// they are a statement of fact rather than something to read.
struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 10) {
            AppMark()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            VStack(spacing: 3) {
                Text(AppInfo.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(AppInfo.versionLine)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(AppInfo.summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 14) {
                if let repository = AppInfo.repository {
                    Link("Source code", destination: repository)
                }
                if let releases = AppInfo.releases {
                    Link("Release notes", destination: releases)
                }
            }
            .font(.system(size: 12))

            Text(AppInfo.copyright)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}
