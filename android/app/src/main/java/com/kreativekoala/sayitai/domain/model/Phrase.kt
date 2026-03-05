package com.kreativekoala.sayitai.domain.model

import androidx.compose.ui.graphics.Color
import com.kreativekoala.sayitai.ui.theme.*

data class Phrase(
    val id: String,
    val text: String,
    val context: String? = null
)

data class PhraseCategory(
    val id: String,
    val name: String,
    val icon: String,
    val color: Color,
    val phrases: List<Phrase>
) {
    companion object {
        val categories = listOf(
            PhraseCategory(
                id = "basics",
                name = "Basics",
                icon = "chat_bubble",
                color = CategoryBasics,
                phrases = listOf(
                    Phrase("b1", "Hello", "General greeting"),
                    Phrase("b2", "Goodbye", "When leaving"),
                    Phrase("b3", "Please", "Polite request"),
                    Phrase("b4", "Thank you", "Expressing gratitude"),
                    Phrase("b5", "You're welcome", "Response to thanks"),
                    Phrase("b6", "Yes", "Affirmative"),
                    Phrase("b7", "No", "Negative"),
                    Phrase("b8", "Excuse me", "Getting attention"),
                    Phrase("b9", "I'm sorry", "Apologizing"),
                    Phrase("b10", "How are you?", "Asking about wellbeing"),
                    Phrase("b11", "I'm fine, thank you", "Response to how are you"),
                    Phrase("b12", "Nice to meet you", "Introduction"),
                    Phrase("b13", "What is your name?", "Asking someone's name"),
                    Phrase("b14", "My name is...", "Introducing yourself"),
                    Phrase("b15", "Do you speak English?", "Checking language"),
                    Phrase("b16", "I don't understand", "When confused"),
                    Phrase("b17", "Please speak slowly", "Asking for clarity"),
                    Phrase("b18", "Can you repeat that?", "Asking for repetition"),
                    Phrase("b19", "Where is the bathroom?", "Finding restroom"),
                    Phrase("b20", "How much does this cost?", "Asking price"),
                    Phrase("b21", "What time is it?", "Asking time"),
                    Phrase("b22", "I need help", "Requesting assistance"),
                    Phrase("b23", "Good morning", "Morning greeting"),
                    Phrase("b24", "Good afternoon", "Afternoon greeting"),
                    Phrase("b25", "Good night", "Evening farewell")
                )
            ),
            PhraseCategory(
                id = "travel",
                name = "Travel",
                icon = "flight",
                color = CategoryTravel,
                phrases = listOf(
                    Phrase("t1", "Where is the airport?", "Finding airport"),
                    Phrase("t2", "Where is the train station?", "Finding train station"),
                    Phrase("t3", "Where is the bus stop?", "Finding bus stop"),
                    Phrase("t4", "I need a taxi", "Getting a cab"),
                    Phrase("t5", "How do I get to...?", "Asking for directions"),
                    Phrase("t6", "Turn left", "Direction"),
                    Phrase("t7", "Turn right", "Direction"),
                    Phrase("t8", "Go straight", "Direction"),
                    Phrase("t9", "Is it far?", "Asking distance"),
                    Phrase("t10", "Can you show me on the map?", "Map assistance"),
                    Phrase("t11", "I'm lost", "When disoriented"),
                    Phrase("t12", "Where can I buy a ticket?", "Getting tickets"),
                    Phrase("t13", "One ticket to...", "Buying ticket"),
                    Phrase("t14", "Round trip ticket", "Two-way travel"),
                    Phrase("t15", "What time does it leave?", "Departure time"),
                    Phrase("t16", "What time does it arrive?", "Arrival time"),
                    Phrase("t17", "Is this seat taken?", "Checking seat"),
                    Phrase("t18", "Where is the exit?", "Finding exit"),
                    Phrase("t19", "Where is the entrance?", "Finding entrance"),
                    Phrase("t20", "Can I have a window seat?", "Seat preference"),
                    Phrase("t21", "Where is the luggage claim?", "At airport"),
                    Phrase("t22", "I have a reservation", "Confirming booking"),
                    Phrase("t23", "Where is the hotel?", "Finding hotel"),
                    Phrase("t24", "Can you recommend a restaurant?", "Food recommendation"),
                    Phrase("t25", "Where is the tourist information?", "Finding info center")
                )
            ),
            PhraseCategory(
                id = "food",
                name = "Food & Dining",
                icon = "restaurant",
                color = CategoryFood,
                phrases = listOf(
                    Phrase("f1", "I would like to order", "Starting order"),
                    Phrase("f2", "The menu, please", "Requesting menu"),
                    Phrase("f3", "What do you recommend?", "Asking for suggestion"),
                    Phrase("f4", "I am vegetarian", "Dietary restriction"),
                    Phrase("f5", "I am vegan", "Dietary restriction"),
                    Phrase("f6", "I have allergies", "Health concern"),
                    Phrase("f7", "No peanuts please", "Allergy warning"),
                    Phrase("f8", "No gluten please", "Dietary restriction"),
                    Phrase("f9", "Is this spicy?", "Checking heat level"),
                    Phrase("f10", "Not too spicy please", "Heat preference"),
                    Phrase("f11", "Water, please", "Ordering drink"),
                    Phrase("f12", "The bill, please", "Requesting check"),
                    Phrase("f13", "Is service included?", "About tip"),
                    Phrase("f14", "Can I pay by card?", "Payment method"),
                    Phrase("f15", "This is delicious", "Complimenting food"),
                    Phrase("f16", "Breakfast", "Meal type"),
                    Phrase("f17", "Lunch", "Meal type"),
                    Phrase("f18", "Dinner", "Meal type"),
                    Phrase("f19", "A table for two, please", "Getting seated"),
                    Phrase("f20", "Do you have a kids menu?", "For children"),
                    Phrase("f21", "Can I have the recipe?", "Asking about dish"),
                    Phrase("f22", "More bread, please", "Requesting more"),
                    Phrase("f23", "To go, please", "Takeaway"),
                    Phrase("f24", "For here, please", "Dine in"),
                    Phrase("f25", "Where is a good coffee shop?", "Finding cafe")
                )
            ),
            PhraseCategory(
                id = "emergency",
                name = "Emergency",
                icon = "emergency",
                color = CategoryEmergency,
                phrases = listOf(
                    Phrase("e1", "Help!", "Urgent call for help"),
                    Phrase("e2", "Call the police!", "Emergency"),
                    Phrase("e3", "Call an ambulance!", "Medical emergency"),
                    Phrase("e4", "I need a doctor", "Medical help"),
                    Phrase("e5", "Where is the hospital?", "Finding hospital"),
                    Phrase("e6", "Where is the pharmacy?", "Finding pharmacy"),
                    Phrase("e7", "I am sick", "Feeling unwell"),
                    Phrase("e8", "I am injured", "When hurt"),
                    Phrase("e9", "I have been robbed", "Reporting theft"),
                    Phrase("e10", "My wallet was stolen", "Reporting theft"),
                    Phrase("e11", "I lost my passport", "Lost document"),
                    Phrase("e12", "Where is the embassy?", "Finding embassy"),
                    Phrase("e13", "I need a lawyer", "Legal help"),
                    Phrase("e14", "There is a fire!", "Fire emergency"),
                    Phrase("e15", "I am allergic to...", "Allergy warning"),
                    Phrase("e16", "I have diabetes", "Medical condition"),
                    Phrase("e17", "I need my medication", "Medical need"),
                    Phrase("e18", "Please call this number", "Contact request"),
                    Phrase("e19", "I don't feel safe", "Safety concern"),
                    Phrase("e20", "Where is the police station?", "Finding police"),
                    Phrase("e21", "I need emergency assistance", "General emergency"),
                    Phrase("e22", "Is there a doctor here?", "Finding medical help"),
                    Phrase("e23", "I can't breathe", "Medical emergency"),
                    Phrase("e24", "I'm having chest pain", "Medical emergency"),
                    Phrase("e25", "Please help me", "Request for help")
                )
            ),
            PhraseCategory(
                id = "shopping",
                name = "Shopping",
                icon = "shopping_cart",
                color = CategoryShopping,
                phrases = listOf(
                    Phrase("s1", "How much is this?", "Asking price"),
                    Phrase("s2", "That's too expensive", "Price negotiation"),
                    Phrase("s3", "Can you give me a discount?", "Asking for deal"),
                    Phrase("s4", "I'm just looking", "Browsing"),
                    Phrase("s5", "Do you have this in another size?", "Size inquiry"),
                    Phrase("s6", "Do you have this in another color?", "Color inquiry"),
                    Phrase("s7", "Where is the fitting room?", "Trying clothes"),
                    Phrase("s8", "I'll take it", "Deciding to buy"),
                    Phrase("s9", "Can I pay in cash?", "Payment method"),
                    Phrase("s10", "Do you accept credit cards?", "Payment method"),
                    Phrase("s11", "Where is the supermarket?", "Finding store"),
                    Phrase("s12", "Where is the shopping mall?", "Finding mall"),
                    Phrase("s13", "What time do you close?", "Store hours"),
                    Phrase("s14", "Can I return this?", "Return policy"),
                    Phrase("s15", "I need a receipt", "Getting receipt"),
                    Phrase("s16", "Is this on sale?", "Checking deals"),
                    Phrase("s17", "Where is the electronics section?", "Finding section"),
                    Phrase("s18", "Do you have a bag?", "Requesting bag"),
                    Phrase("s19", "Can you gift wrap this?", "Gift wrapping"),
                    Phrase("s20", "I'm looking for a gift", "Gift shopping")
                )
            ),
            PhraseCategory(
                id = "accommodation",
                name = "Accommodation",
                icon = "hotel",
                color = CategoryAccommodation,
                phrases = listOf(
                    Phrase("a1", "I have a reservation", "Checking in"),
                    Phrase("a2", "I would like to book a room", "Making reservation"),
                    Phrase("a3", "Single room, please", "Room type"),
                    Phrase("a4", "Double room, please", "Room type"),
                    Phrase("a5", "How much per night?", "Asking rate"),
                    Phrase("a6", "Is breakfast included?", "Amenities"),
                    Phrase("a7", "Is there WiFi?", "Amenities"),
                    Phrase("a8", "What is the WiFi password?", "Internet access"),
                    Phrase("a9", "What time is checkout?", "Checkout info"),
                    Phrase("a10", "Can I have a wake-up call?", "Service request"),
                    Phrase("a11", "The room is not clean", "Complaint"),
                    Phrase("a12", "The air conditioning doesn't work", "Maintenance"),
                    Phrase("a13", "Can I have extra towels?", "Service request"),
                    Phrase("a14", "Where is the elevator?", "Finding elevator"),
                    Phrase("a15", "My key doesn't work", "Key problem"),
                    Phrase("a16", "Can I extend my stay?", "Extending booking"),
                    Phrase("a17", "I would like to check out", "Leaving"),
                    Phrase("a18", "Where can I park?", "Parking"),
                    Phrase("a19", "Is there a gym?", "Amenities"),
                    Phrase("a20", "Is there a pool?", "Amenities")
                )
            )
        )
    }
}
