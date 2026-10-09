import Foundation

/// Message templates from the partners guide (Guides/4-partners.md), filled in with the partner's name.
enum MessageTemplate: String, CaseIterable, Identifiable {
    case thanksAfterMeeting, followUp, thankYouCard, invite, oneTimeThanks, englishThanks, stopping
    var id: String { rawValue }

    var title: String {
        switch self {
        case .thanksAfterMeeting: "A · Thanks after a meeting"
        case .followUp: "B · Follow-up call"
        case .thankYouCard: "C · Thank-you card, new partner"
        case .invite: "D · Invitation (C-contacts)"
        case .oneTimeThanks: "E · Thanks for a one-time gift"
        case .englishThanks: "F · Thank you (English)"
        case .stopping: "G · Partner stops"
        }
    }

    func text(for p: Partner) -> String {
        let naam = p.firstName.isEmpty ? "[naam]" : p.firstName
        switch self {
        case .thanksAfterMeeting:
            return "Hoi \(naam), dank je wel voor je tijd vandaag. Het was fijn om mijn verhaal met je te delen. [Persoonlijk detail uit het gesprek.] Ik hoor graag wat je besluit, en ik bel je [dag] even. Hartelijke groet, Ruben"
        case .followUp:
            return "Hoi \(naam), met Ruben. Ik beloofde je te bellen over onze afspraak van [dag]. Heb je er al over kunnen nadenken?\n\n(Ja) Wat fijn! Weet je al welk bedrag? Zal ik je de gegevens nog even sturen?\n(Nee) Helemaal goed, dank je dat je erover nagedacht hebt. Wil je wel de nieuwsbrief ontvangen?"
        case .thankYouCard:
            return "Lieve \(naam),\n\nIk heb je eerste gift ontvangen, en ik wil je echt bedanken. Dankzij jou ga ik niet alleen naar Queenstown, maar als deel van een team. [Eén zin over wat je gift mogelijk maakt.] Ik ga je elke maand op de hoogte houden, en je mag me altijd een berichtje sturen met een vraag of gebedspunt.\n\nMet veel dank,\nRuben"
        case .invite:
            return "Hoi \(naam), lang niet gesproken! [Persoonlijke zin.] Ik wilde je laten weten dat ik in januari fulltime naar Queenstown, Nieuw-Zeeland, ga met Jeugd met een Opdracht. Ik heb er een korte nieuwsbrief over geschreven: [link] Ik zou het heel leuk vinden om je er een keer meer over te vertellen, eventueel via een videocall. En als je wilt meelezen, kun je je op de site aanmelden voor de maandelijkse nieuwsbrief. Groetjes, Ruben"
        case .oneTimeThanks:
            return "Hoi \(naam), ik zag je gift voor mijn vertrek binnenkomen. Wat ontzettend lief, dank je wel! Het gaat naar [ticket / visum / verzekering]. Ik houd je op de hoogte via de nieuwsbrief."
        case .englishThanks:
            let name = p.firstName.isEmpty ? "[name]" : p.firstName
            return "Dear \(name), your first gift has come in and I want to say a real thank you. Because of you I'm not going to Queenstown alone, but as part of a team. I'll keep you posted every month, and feel free to message me any time with a question or something to pray about. With gratitude, Ruben"
        case .stopping:
            return "Hoi \(naam), dank je wel dat je het laat weten. Ik ben ontzettend dankbaar voor je steun de afgelopen [periode], het heeft echt verschil gemaakt. Je blijft natuurlijk van harte welkom op de nieuwsbrief. Alle goeds!"
        }
    }

    /// The templates that fit where this partner is.
    static func suggested(for p: Partner) -> [MessageTemplate] {
        switch p.stageValue {
        case .idea, .toAsk: return [.invite, .thanksAfterMeeting]
        case .asked: return [.thanksAfterMeeting, .followUp]
        case .thinking: return [.followUp, .thanksAfterMeeting]
        case .committed, .giving:
            return p.monthlyCents > 0 ? [.thankYouCard, .englishThanks, .stopping] : [.oneTimeThanks, .englishThanks]
        case .declined, .paused: return [.invite, .stopping]
        }
    }
}
