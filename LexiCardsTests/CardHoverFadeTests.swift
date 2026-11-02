import Foundation
import Testing

@testable import LexiCards

@MainActor
struct CardHoverFadeTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test
    func passingOverTheCardDoesNotFadeIt() {
        var fade = CardHoverFade()

        #expect(sample(&fade, at: 0) == false)
        #expect(sample(&fade, at: 0.1) == false)
        #expect(sample(&fade, at: 0.12, inside: false) == false)
        #expect(sample(&fade, at: 0.2) == false)
    }

    @Test
    func restingOnTheCardFadesItAndLeavingBringsItBack() {
        var fade = CardHoverFade()

        _ = sample(&fade, at: 0)
        #expect(sample(&fade, at: CardHoverFade.delay) == true)
        #expect(sample(&fade, at: 5) == true)
        #expect(sample(&fade, at: 5.1, inside: false) == false)
    }

    @Test
    func optionBringsTheCardBackWhileThePointerStaysOnIt() {
        var fade = CardHoverFade()
        _ = sample(&fade, at: 0)
        _ = sample(&fade, at: 1)

        #expect(sample(&fade, at: 1.1, option: true) == false)
        #expect(sample(&fade, at: 1.2, option: true) == false)
    }

    @Test
    func aDragStartedWithOptionSurvivesReleasingTheKey() {
        var fade = CardHoverFade()
        _ = sample(&fade, at: 0, option: true, pressed: true)

        #expect(sample(&fade, at: 1, pressed: true) == false)
        #expect(sample(&fade, at: 2, pressed: true) == false)
    }

    @Test
    func aPressThatBeganOnTheAppUnderneathKeepsTheCardFaded() {
        var fade = CardHoverFade()
        _ = sample(&fade, at: 0)
        _ = sample(&fade, at: 1)

        #expect(sample(&fade, at: 1.1, inside: false, pressed: true) == true)
    }

    @Test
    func aRecallCardDoesNotStartFading() {
        var fade = CardHoverFade()

        _ = sample(&fade, at: 0, recalling: true)
        #expect(sample(&fade, at: 1, recalling: true) == false)
    }

    @Test
    func aSessionThatBeginsUnderTheFadedCardWaitsForThePointerToLeave() {
        var fade = CardHoverFade()
        _ = sample(&fade, at: 0)
        _ = sample(&fade, at: 1)

        #expect(sample(&fade, at: 1.1, recalling: true) == true)
        #expect(sample(&fade, at: 1.2, inside: false, recalling: true) == false)
        #expect(sample(&fade, at: 1.3, recalling: true) == false)
    }

    @Test
    func turningTheSettingOffBringsTheCardBack() {
        var fade = CardHoverFade()
        _ = sample(&fade, at: 0)
        _ = sample(&fade, at: 1)

        #expect(sample(&fade, at: 1.1, enabled: false) == false)
    }

    @Test
    func theSettingIsOnByDefault() {
        withIsolatedSettings {
            #expect(AppSettings.shared.cardFadesOnHover)
        }
    }

    private func sample(
        _ fade: inout CardHoverFade,
        at seconds: TimeInterval,
        inside: Bool = true,
        option: Bool = false,
        pressed: Bool = false,
        enabled: Bool = true,
        recalling: Bool = false
    ) -> Bool {
        fade.update(
            pointerInside: inside,
            optionHeld: option,
            buttonPressed: pressed,
            isEnabled: enabled,
            isRecalling: recalling,
            now: start.addingTimeInterval(seconds)
        )
    }
}
