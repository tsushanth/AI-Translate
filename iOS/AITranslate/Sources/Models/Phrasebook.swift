import Foundation

/// A category of phrases in the phrasebook
struct PhraseCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let phrases: [Phrase]

    /// Number of phrases in this category
    var phraseCount: Int { phrases.count }
}

/// A single phrase that can be translated
struct Phrase: Identifiable, Hashable {
    let id: String
    let text: String
    let context: String?

    init(id: String = UUID().uuidString, text: String, context: String? = nil) {
        self.id = id
        self.text = text
        self.context = context
    }
}

// MARK: - Phrasebook Data

/// Static phrasebook data
enum PhrasebookData {

    /// All available categories
    static let categories: [PhraseCategory] = [
        basics,
        travel,
        food,
        emergency,
        shopping,
        accommodation
    ]

    // MARK: - Basics

    static let basics = PhraseCategory(
        id: "basics",
        name: "Basics",
        icon: "text.bubble",
        color: "blue",
        phrases: [
            Phrase(text: "Hello", context: "Greeting"),
            Phrase(text: "Goodbye", context: "Farewell"),
            Phrase(text: "Good morning", context: "Morning greeting"),
            Phrase(text: "Good afternoon", context: "Afternoon greeting"),
            Phrase(text: "Good evening", context: "Evening greeting"),
            Phrase(text: "Good night", context: "Night farewell"),
            Phrase(text: "Please", context: "Polite request"),
            Phrase(text: "Thank you", context: "Gratitude"),
            Phrase(text: "Thank you very much", context: "Strong gratitude"),
            Phrase(text: "You're welcome", context: "Response to thanks"),
            Phrase(text: "Yes", context: "Affirmative"),
            Phrase(text: "No", context: "Negative"),
            Phrase(text: "Excuse me", context: "Getting attention"),
            Phrase(text: "I'm sorry", context: "Apology"),
            Phrase(text: "How are you?", context: "Asking about wellbeing"),
            Phrase(text: "I'm fine, thank you", context: "Response to how are you"),
            Phrase(text: "Nice to meet you", context: "Introduction"),
            Phrase(text: "What is your name?", context: "Asking someone's name"),
            Phrase(text: "My name is...", context: "Introducing yourself"),
            Phrase(text: "I don't understand", context: "Confusion"),
            Phrase(text: "Do you speak English?", context: "Language question"),
            Phrase(text: "I don't speak [language] well", context: "Language limitation"),
            Phrase(text: "Can you speak more slowly?", context: "Asking for clarity"),
            Phrase(text: "Can you repeat that?", context: "Asking for repetition"),
            Phrase(text: "How do you say this?", context: "Asking for translation"),
        ]
    )

    // MARK: - Travel

    static let travel = PhraseCategory(
        id: "travel",
        name: "Travel",
        icon: "airplane",
        color: "orange",
        phrases: [
            Phrase(text: "Where is the airport?", context: "Directions"),
            Phrase(text: "Where is the train station?", context: "Directions"),
            Phrase(text: "Where is the bus stop?", context: "Directions"),
            Phrase(text: "How do I get to...?", context: "Asking directions"),
            Phrase(text: "Is it far from here?", context: "Distance question"),
            Phrase(text: "Can you show me on the map?", context: "Map assistance"),
            Phrase(text: "Turn left", context: "Direction"),
            Phrase(text: "Turn right", context: "Direction"),
            Phrase(text: "Go straight", context: "Direction"),
            Phrase(text: "I need a taxi", context: "Transportation"),
            Phrase(text: "How much is a ticket to...?", context: "Ticket price"),
            Phrase(text: "One ticket, please", context: "Buying ticket"),
            Phrase(text: "Round trip ticket", context: "Return ticket"),
            Phrase(text: "What time does it leave?", context: "Departure time"),
            Phrase(text: "What time does it arrive?", context: "Arrival time"),
            Phrase(text: "Is this seat taken?", context: "Seat availability"),
            Phrase(text: "Where is the bathroom?", context: "Finding restroom"),
            Phrase(text: "I'm lost", context: "Being lost"),
            Phrase(text: "Can you help me?", context: "Asking for help"),
            Phrase(text: "I'm looking for...", context: "Searching"),
            Phrase(text: "Where can I rent a car?", context: "Car rental"),
            Phrase(text: "I have a reservation", context: "Booking confirmation"),
            Phrase(text: "My flight is delayed", context: "Flight status"),
            Phrase(text: "Where is the baggage claim?", context: "Airport"),
            Phrase(text: "I lost my luggage", context: "Lost items"),
        ]
    )

    // MARK: - Food

    static let food = PhraseCategory(
        id: "food",
        name: "Food & Dining",
        icon: "fork.knife",
        color: "green",
        phrases: [
            Phrase(text: "A table for two, please", context: "Restaurant seating"),
            Phrase(text: "Can I see the menu?", context: "Ordering"),
            Phrase(text: "What do you recommend?", context: "Recommendations"),
            Phrase(text: "I would like to order...", context: "Ordering"),
            Phrase(text: "I'm vegetarian", context: "Dietary preference"),
            Phrase(text: "I'm vegan", context: "Dietary preference"),
            Phrase(text: "I have a food allergy", context: "Allergy warning"),
            Phrase(text: "I'm allergic to nuts", context: "Specific allergy"),
            Phrase(text: "I'm allergic to shellfish", context: "Specific allergy"),
            Phrase(text: "Does this contain gluten?", context: "Dietary question"),
            Phrase(text: "Is this spicy?", context: "Food question"),
            Phrase(text: "Not too spicy, please", context: "Food preference"),
            Phrase(text: "Can I have the bill, please?", context: "Paying"),
            Phrase(text: "Is service included?", context: "Tipping question"),
            Phrase(text: "This is delicious!", context: "Compliment"),
            Phrase(text: "A glass of water, please", context: "Ordering drink"),
            Phrase(text: "Coffee, please", context: "Ordering drink"),
            Phrase(text: "Tea, please", context: "Ordering drink"),
            Phrase(text: "A beer, please", context: "Ordering drink"),
            Phrase(text: "A glass of wine, please", context: "Ordering drink"),
            Phrase(text: "Breakfast", context: "Meal"),
            Phrase(text: "Lunch", context: "Meal"),
            Phrase(text: "Dinner", context: "Meal"),
            Phrase(text: "I'm hungry", context: "State"),
            Phrase(text: "I'm thirsty", context: "State"),
        ]
    )

    // MARK: - Emergency

    static let emergency = PhraseCategory(
        id: "emergency",
        name: "Emergency",
        icon: "cross.case",
        color: "red",
        phrases: [
            Phrase(text: "Help!", context: "Emergency call"),
            Phrase(text: "Call the police!", context: "Emergency"),
            Phrase(text: "Call an ambulance!", context: "Medical emergency"),
            Phrase(text: "Call the fire department!", context: "Fire emergency"),
            Phrase(text: "There's been an accident", context: "Accident report"),
            Phrase(text: "I need a doctor", context: "Medical need"),
            Phrase(text: "I need to go to the hospital", context: "Medical need"),
            Phrase(text: "Where is the nearest hospital?", context: "Finding hospital"),
            Phrase(text: "Where is the nearest pharmacy?", context: "Finding pharmacy"),
            Phrase(text: "I'm not feeling well", context: "Feeling sick"),
            Phrase(text: "I have a headache", context: "Symptom"),
            Phrase(text: "I have a fever", context: "Symptom"),
            Phrase(text: "I have a stomachache", context: "Symptom"),
            Phrase(text: "I'm in pain", context: "Pain"),
            Phrase(text: "It hurts here", context: "Indicating pain location"),
            Phrase(text: "I need medicine", context: "Medical need"),
            Phrase(text: "I've lost my passport", context: "Lost document"),
            Phrase(text: "I've been robbed", context: "Crime report"),
            Phrase(text: "My wallet was stolen", context: "Theft report"),
            Phrase(text: "Where is the embassy?", context: "Finding embassy"),
            Phrase(text: "I need to contact my embassy", context: "Embassy contact"),
            Phrase(text: "This is an emergency", context: "Urgency"),
            Phrase(text: "Please help me", context: "Asking for help"),
            Phrase(text: "I'm having an allergic reaction", context: "Medical emergency"),
            Phrase(text: "Call my family", context: "Emergency contact"),
        ]
    )

    // MARK: - Shopping

    static let shopping = PhraseCategory(
        id: "shopping",
        name: "Shopping",
        icon: "bag",
        color: "purple",
        phrases: [
            Phrase(text: "How much does this cost?", context: "Price inquiry"),
            Phrase(text: "That's too expensive", context: "Price negotiation"),
            Phrase(text: "Do you have a cheaper one?", context: "Price negotiation"),
            Phrase(text: "Can you give me a discount?", context: "Bargaining"),
            Phrase(text: "I'm just looking", context: "Browsing"),
            Phrase(text: "I'll take this one", context: "Making purchase"),
            Phrase(text: "Do you accept credit cards?", context: "Payment method"),
            Phrase(text: "Can I pay in cash?", context: "Payment method"),
            Phrase(text: "Where is the fitting room?", context: "Trying on clothes"),
            Phrase(text: "Do you have this in a different size?", context: "Size inquiry"),
            Phrase(text: "Do you have this in a different color?", context: "Color inquiry"),
            Phrase(text: "This is too small", context: "Size issue"),
            Phrase(text: "This is too big", context: "Size issue"),
            Phrase(text: "Can I return this?", context: "Return policy"),
            Phrase(text: "I need a receipt", context: "Receipt request"),
            Phrase(text: "Where is the supermarket?", context: "Finding store"),
            Phrase(text: "What time do you close?", context: "Store hours"),
            Phrase(text: "What time do you open?", context: "Store hours"),
            Phrase(text: "Is there a sale?", context: "Discounts"),
            Phrase(text: "I'm looking for...", context: "Finding item"),
        ]
    )

    // MARK: - Accommodation

    static let accommodation = PhraseCategory(
        id: "accommodation",
        name: "Accommodation",
        icon: "bed.double",
        color: "indigo",
        phrases: [
            Phrase(text: "I have a reservation", context: "Check-in"),
            Phrase(text: "I don't have a reservation", context: "Walk-in"),
            Phrase(text: "Do you have any rooms available?", context: "Availability"),
            Phrase(text: "How much is a room per night?", context: "Price"),
            Phrase(text: "I'd like a single room", context: "Room type"),
            Phrase(text: "I'd like a double room", context: "Room type"),
            Phrase(text: "Is breakfast included?", context: "Amenities"),
            Phrase(text: "Is there WiFi?", context: "Amenities"),
            Phrase(text: "What is the WiFi password?", context: "WiFi access"),
            Phrase(text: "What time is checkout?", context: "Checkout time"),
            Phrase(text: "Can I have a wake-up call?", context: "Service request"),
            Phrase(text: "The room is not clean", context: "Complaint"),
            Phrase(text: "The air conditioning doesn't work", context: "Maintenance"),
            Phrase(text: "There's no hot water", context: "Maintenance"),
            Phrase(text: "Can I have extra towels?", context: "Request"),
            Phrase(text: "Can I have extra pillows?", context: "Request"),
            Phrase(text: "Where is the elevator?", context: "Finding elevator"),
            Phrase(text: "I'd like to extend my stay", context: "Extension"),
            Phrase(text: "I'd like to check out", context: "Checkout"),
            Phrase(text: "Can I leave my luggage here?", context: "Luggage storage"),
        ]
    )

    /// Find a category by ID
    static func category(withId id: String) -> PhraseCategory? {
        categories.first { $0.id == id }
    }

    /// Search phrases across all categories
    static func search(query: String) -> [(category: PhraseCategory, phrase: Phrase)] {
        guard !query.isEmpty else { return [] }

        let lowercased = query.lowercased()
        var results: [(category: PhraseCategory, phrase: Phrase)] = []

        for category in categories {
            for phrase in category.phrases {
                if phrase.text.lowercased().contains(lowercased) ||
                   (phrase.context?.lowercased().contains(lowercased) ?? false) {
                    results.append((category: category, phrase: phrase))
                }
            }
        }

        return results
    }
}
