class_name Careers
extends RefCounted
## Career tracks: ten levels each (six shared, four on a branch) with a title and hourly pay, a work schedule
## (Monday to Friday) and the skill needed for promotions.

const INFO := {
	"culinary": {
		"label": "Culinary",
		"skill": "cooking",
		"start": 12, "end": 20,
		"levels": [["Dishwasher", 14], ["Prep Cook", 18], ["Line Cook", 23], ["Sous Chef", 30], ["Chef", 38], ["Executive Sous Chef", 46]],
		"description": "From scrubbing pots to running the kitchen. Cooking helps you rise.",
	},
	"tech": {
		"label": "Tech Guru",
		"skill": "programming",
		"start": 9, "end": 17,
		"levels": [["Tech Support", 16], ["Junior Developer", 21], ["Developer", 28], ["Senior Developer", 36], ["Lead Developer", 45], ["Technical Architect", 55]],
		"description": "Fix printers today, design systems tomorrow. Logic helps you rise.",
	},
	"painter": {
		"label": "Painter",
		"skill": "painting",
		"start": 10, "end": 16,
		"levels": [["Canvas Stretcher", 12], ["Gallery Assistant", 16], ["Painter", 21], ["Artist", 28], ["Acclaimed Artist", 36], ["Exhibited Artist", 44]],
		"description": "Make a name in the art world. Painting helps you rise.",
	},
	"business": {
		"label": "Business",
		"skill": "charisma",
		"start": 9, "end": 17,
		"levels": [["Mailroom Clerk", 15], ["Office Assistant", 20], ["Account Manager", 27], ["Department Manager", 35], ["Regional Director", 44], ["Vice President", 54]],
		"description": "Climb the corporate ladder. Charisma helps you rise.",
	},
	"athlete": {
		"label": "Athlete",
		"skill": "fitness",
		"start": 7, "end": 13,
		"levels": [["Waterboy", 13], ["Minor Leaguer", 18], ["Rookie", 24], ["Starter", 31], ["Veteran", 39], ["Team Captain", 48]],
		"description": "Train hard, play harder. Fitness helps you rise.",
	},
	"entertainer": {
		"label": "Entertainer",
		"skill": "guitar",
		"start": 14, "end": 22,
		"levels": [["Street Performer", 11], ["Open Mic Hopeful", 15], ["Opening Act", 20], ["Featured Act", 27], ["Headliner", 35], ["Star", 44]],
		"description": "From busking to sold-out shows. Guitar helps you rise.",
	},
	"writer": {
		"label": "Writer",
		"skill": "writing",
		"start": 10, "end": 16,
		"levels": [["Copy Editor", 14], ["Blogger", 18], ["Freelancer", 23], ["Staff Writer", 29], ["Published Writer", 37], ["Acclaimed Writer", 46]],
		"description": "Words on paper, money in the bank. Writing helps you rise.",
	},
	"astronaut": {
		"label": "Astronaut",
		"skill": "logic",
		"start": 8, "end": 16,
		"levels": [["Space Cadet", 16], ["Flight Trainee", 21], ["Flight Engineer", 28], ["Mission Specialist", 36], ["Pilot", 45], ["Station Commander", 56]],
		"description": "Reach for the stars. Logic helps you rise.",
	},
	"criminal": {
		"label": "Criminal",
		"skill": "mischief",
		"start": 20, "end": 3,
		"levels": [["Lookout", 15], ["Pickpocket", 19], ["Getaway Driver", 25], ["Safecracker", 32], ["Con Artist", 40], ["Cat Burglar", 50]],
		"description": "Work the night shift on the wrong side of the law. Mischief helps you rise.",
	},
	"secret_agent": {
		"label": "Secret Agent",
		"skill": "charisma",
		"start": 9, "end": 17,
		"levels": [["Training Agent", 17], ["Desk Agent", 22], ["Field Analyst", 29], ["Field Agent", 37], ["Undercover Agent", 46], ["Senior Agent", 56]],
		"description": "License to charm. Charisma and Logic help you rise.",
	},
	"style_influencer": {
		"label": "Style Influencer",
		"skill": "writing",
		"start": 10, "end": 17,
		"levels": [["Style Novice", 14], ["Style Assistant", 18], ["Fashion Blogger", 24], ["Rising Star", 31], ["Style Expert", 39], ["Fashion Insider", 48]],
		"description": "Set the trends everyone follows. Writing and Charisma help you rise.",
	},
	"school": {
		"label": "Grade School", "skill": "logic", "start": 8, "end": 15,
		"levels": [["Student", 0]], "description": "Reading, writing and recess.",
	},
	"high_school": {
		"label": "High School", "skill": "logic", "start": 8, "end": 15,
		"levels": [["Student", 0]], "description": "Homework, friends and a lot of growing up.",
	},
}
const ORDER: Array[String] = ["culinary", "tech", "painter", "business", "athlete", "entertainer", "writer", "astronaut", "criminal", "secret_agent", "style_influencer"]
## How hard the Sim works: [label, performance multiplier, moodlet on return].
const WORK_STYLES := {
	"hard": ["Work Hard", 1.6, ["work_hard", "tense", 1, "Worked Hard", "Tiring, but it'll pay off.", 240.0]],
	"normal": ["Normal", 1.0, []],
	"easy": ["Take It Easy", 0.4, ["work_easy", "happy", 1, "Easy Day", "Barely broke a sweat today.", 180.0]],
}
## A daily task per career: done before the shift, it gives a performance boost.
## {text, skill, xp} (practise that skill) or {text, mood} (arrive in that mood).
const DAILY_TASKS := {
	"culinary": {"text": "Practise Cooking", "skill": "cooking", "xp": 40.0},
	"tech": {"text": "Practise Programming", "skill": "programming", "xp": 40.0},
	"painter": {"text": "Paint something", "skill": "painting", "xp": 40.0},
	"business": {"text": "Go to work Confident", "mood": "confident"},
	"athlete": {"text": "Work out", "skill": "fitness", "xp": 40.0},
	"entertainer": {"text": "Practise Comedy", "skill": "comedy", "xp": 30.0},
	"writer": {"text": "Practise Writing", "skill": "writing", "xp": 40.0},
	"astronaut": {"text": "Practise Logic", "skill": "logic", "xp": 40.0},
	"criminal": {"text": "Pull a prank", "skill": "mischief", "xp": 30.0},
	"secret_agent": {"text": "Practise Charisma", "skill": "charisma", "xp": 40.0},
	"style_influencer": {"text": "Write a style post", "skill": "writing", "xp": 40.0},
}
const TASK_BONUS := 12.0

## Things that come up during a shift: [title, text, [[choice, perf, moodlet or [], needs {skill: level}]...]].
## A choice with a skill requirement succeeds only if the Sim has it; otherwise the
## second (failure) performance and moodlet apply.
const EVENTS := [
	["Extra Project", "The boss is asking for a volunteer to take on an extra project.", [
		["Volunteer", 15.0, ["overworked", "tense", 1, "Extra Work", "That project is a lot.", 240.0]],
		["Keep your head down", 0.0, []],
	]],
	["Stolen Credit", "A coworker just presented %s's idea as their own!", [
		["Speak up", 12.0, ["stood_up", "confident", 1, "Stood My Ground", "Credit where it's due.", 180.0], {"charisma": 3}, -6.0, ["credit_stolen", "angry", 1, "Credit Stolen", "That was MY idea.", 180.0]],
		["Let it go", 0.0, ["credit_stolen", "sad", 1, "Overlooked", "Nobody noticed.", 120.0]],
	]],
	["Pizza Party", "Someone brought pizza to the break room.", [
		["Grab a slice", 0.0, ["pizza_party", "happy", 1, "Office Pizza", "Free food is the best food.", 120.0]],
		["Keep working", 8.0, []],
	]],
	["Jammed Printer", "The printer jammed right before a big meeting.", [
		["Fix it yourself", 10.0, ["fixed_it", "confident", 1, "Handy at Work", "Who needs IT?", 120.0], {"handiness": 3}, -5.0, ["ink_mess", "embarrassed", 1, "Covered in Toner", "That did not go well.", 120.0]],
		["Call IT", 0.0, []],
	]],
	["Team Lunch", "The team is heading out for lunch together.", [
		["Join them", 5.0, ["team_lunch", "happy", 1, "Team Spirit", "Good people to work with.", 180.0]],
		["Eat at your desk", 6.0, ["lonely_lunch", "sad", 1, "Desk Lunch", "Bit lonely.", 90.0]],
	]],
]


## Events that only come up in a particular career, as in the reference.
const CAREER_EVENTS := {
	"culinary": [
		["Dinner Rush", "The restaurant is packed and orders are piling up.", [
			["Take charge of the line", 14.0, ["kitchen_hero", "confident", 1, "Kitchen Hero", "Not a single order late!", 180.0], {"cooking": 4}, -6.0, ["burnt_order", "embarrassed", 1, "Burnt the Orders", "The critics noticed.", 150.0]],
			["Keep your head down", 0.0, []],
		]],
	],
	"tech": [
		["Server Outage", "The servers are down and everyone is panicking.", [
			["Debug it yourself", 14.0, ["saved_the_day", "confident", 1, "Saved the Day", "Back online in minutes!", 180.0], {"programming": 4}, -6.0, ["crashed_more", "tense", 1, "Made It Worse", "Oops, wrong cable.", 150.0]],
			["Wait for the senior devs", 0.0, []],
		]],
	],
	"painter": [
		["Gallery Opening", "A gallery owner wants to see some of your work tonight.", [
			["Pitch your best piece", 14.0, ["gallery_deal", "inspired", 1, "Gallery Deal", "My art on a gallery wall!", 180.0], {"painting": 4}, -6.0, ["art_snub", "sad", 1, "Snubbed", "They didn't get it.", 150.0]],
			["Politely decline", 0.0, []],
		]],
	],
	"business": [
		["Big Pitch", "A major client is in the building and the boss needs someone to present.", [
			["Give the pitch", 14.0, ["closed_deal", "confident", 1, "Closed the Deal", "They signed on the spot!", 180.0], {"charisma": 4}, -6.0, ["pitch_flop", "embarrassed", 1, "Pitch Flopped", "Silence in the room...", 150.0]],
			["Let a colleague present", 0.0, []],
		]],
	],
	"athlete": [
		["Big Game", "The coach puts you in for the final minutes of a close game.", [
			["Go for the winning play", 14.0, ["game_winner", "confident", 1, "Game Winner", "The crowd went wild!", 180.0], {"fitness": 4}, -6.0, ["choked", "embarrassed", 1, "Choked", "Missed the easy one.", 150.0]],
			["Play it safe", 0.0, []],
		]],
	],
	"entertainer": [
		["Heckler", "Someone in the crowd keeps heckling your act.", [
			["Roast them back", 14.0, ["killed_it", "playful", 1, "Killed It", "The audience loved it.", 180.0], {"comedy": 4}, -6.0, ["bombed", "embarrassed", 1, "Bombed", "Nobody laughed.", 150.0]],
			["Ignore it and carry on", 0.0, []],
		]],
	],
	"writer": [
		["Tight Deadline", "Your editor wants the whole piece by the end of the day.", [
			["Write through lunch", 14.0, ["deadline_met", "focused", 1, "Deadline Met", "Every word in place.", 180.0], {"writing": 4}, -6.0, ["rushed_piece", "tense", 1, "Rushed Piece", "That was sloppy.", 150.0]],
			["Ask for an extension", 0.0, []],
		]],
	],
	"astronaut": [
		["Simulator Malfunction", "The flight simulator glitches mid-mission.", [
			["Fly it manually", 14.0, ["ace_pilot", "confident", 1, "Ace Pilot", "Smooth landing!", 180.0], {"logic": 4}, -6.0, ["sim_crash", "embarrassed", 1, "Crashed the Sim", "Thankfully it wasn't real.", 150.0]],
			["Abort the run", 0.0, []],
		]],
	],
	"criminal": [
		["Tough Lock", "The safe on tonight's job has a new kind of lock.", [
			["Crack it", 14.0, ["clean_job", "confident", 1, "Clean Job", "In and out without a trace.", 180.0], {"mischief": 4}, -6.0, ["alarm_tripped", "tense", 1, "Tripped the Alarm", "Run!", 150.0]],
			["Walk away", 0.0, []],
		]],
	],
	"secret_agent": [
		["Cover Blown?", "A suspicious contact asks too many questions.", [
			["Charm your way out", 14.0, ["smooth_operator", "confident", 1, "Smooth Operator", "They never suspected a thing.", 180.0], {"charisma": 4}, -6.0, ["cover_blown", "tense", 1, "Cover Almost Blown", "Too close.", 150.0]],
			["Call for extraction", 0.0, []],
		]],
	],
	"style_influencer": [
		["Viral Moment", "A celebrity reposted your look and the comments are exploding.", [
			["Post a follow-up right away", 14.0, ["went_viral", "playful", 1, "Went Viral", "So many new followers!", 180.0], {"writing": 4}, -6.0, ["ratioed", "embarrassed", 1, "Ratioed", "The comments turned on me.", 150.0]],
			["Let it settle", 0.0, []],
		]],
	],
}


## Events for each career branch (from level 7), as in the reference.
const BRANCH_EVENTS := {
	"culinary:0": [
		["Food Critic", "A famous food critic just sat down at table four.", [["Cook them a signature dish", 16.0, ["rave_review", "confident", 1, "Rave Review", "Five stars!", 180.0], {"cooking": 7}, -8.0, ["bad_review", "sad", 1, "Bad Review", "Ouch.", 150.0]], ["Stick to the menu", 0.0, []]]],
	],
	"culinary:1": [
		["Cocktail Contest", "The bar is entering a cocktail competition tonight.", [["Invent a new cocktail", 16.0, ["cocktail_champ", "playful", 1, "Cocktail Champ", "They loved it!", 180.0], {"mixology": 7}, -8.0, ["sour_mix", "embarrassed", 1, "Sour Mix", "Too much lime...", 150.0]], ["Make the classics", 0.0, []]]],
	],
	"tech:0": [
		["Investor Demo", "Investors want a live demo of the start-up's app.", [["Demo the unfinished feature", 16.0, ["funded", "confident", 1, "Funded!", "They're in!", 180.0], {"programming": 7}, -8.0, ["demo_crash", "embarrassed", 1, "Demo Crashed", "Live on stage.", 150.0]], ["Show the safe build", 0.0, []]]],
	],
	"tech:1": [
		["Tournament Final", "Your team made the eSports final.", [["Go for the risky strategy", 16.0, ["champions", "confident", 1, "Champions", "GG!", 180.0], {"gaming": 7}, -8.0, ["lost_final", "sad", 1, "Lost the Final", "So close.", 150.0]], ["Play defensively", 0.0, []]]],
	],
	"painter:0": [
		["Commission", "A wealthy collector wants a realistic portrait by Friday.", [["Accept and paint it", 16.0, ["masterpiece", "inspired", 1, "Masterpiece", "Lifelike!", 180.0], {"painting": 7}, -8.0, ["odd_portrait", "embarrassed", 1, "Odd Portrait", "Is that a nose?", 150.0]], ["Turn it down", 0.0, []]]],
	],
	"painter:1": [
		["Charity Auction", "You're hosting an art auction for charity.", [["Work the room for bigger bids", 16.0, ["record_bids", "confident", 1, "Record Bids", "Every piece sold!", 180.0], {"charisma": 7}, -8.0, ["empty_room", "sad", 1, "Quiet Auction", "Hardly any bids.", 150.0]], ["Let the art speak", 0.0, []]]],
	],
	"business:0": [
		["Restructure", "The board wants you to reorganise a struggling department.", [["Lead the restructure", 16.0, ["turned_around", "confident", 1, "Turned It Around", "Profits are up!", 180.0], {"charisma": 7}, -8.0, ["staff_revolt", "tense", 1, "Staff Revolt", "Everyone's upset.", 150.0]], ["Keep things as they are", 0.0, []]]],
	],
	"business:1": [
		["Hot Tip", "A colleague whispers about a promising young company.", [["Invest big", 16.0, ["smart_money", "confident", 1, "Smart Money", "It took off!", 180.0], {"logic": 7}, -8.0, ["bad_bet", "sad", 1, "Bad Bet", "It tanked.", 150.0]], ["Do more research", 0.0, []]]],
	],
	"athlete:0": [
		["Posing Contest", "There's a bodybuilding competition this afternoon.", [["Enter and flex", 16.0, ["champion_pose", "confident", 1, "Champion Pose", "Gold medal!", 180.0], {"fitness": 7}, -8.0, ["pulled_muscle", "uncomfortable", 1, "Pulled Muscle", "Ow.", 150.0]], ["Skip it this time", 0.0, []]]],
	],
	"athlete:1": [
		["Contract Talks", "Your agent is renegotiating your contract.", [["Push for a bigger deal", 16.0, ["big_contract", "confident", 1, "Big Contract", "Worth every penny.", 180.0], {"fitness": 7}, -8.0, ["benched", "sad", 1, "Benched", "They called my bluff.", 150.0]], ["Take the offer", 0.0, []]]],
	],
	"entertainer:0": [
		["Comedy Special", "A network wants you to film a comedy special.", [["Try all-new material", 16.0, ["special_hit", "playful", 1, "Hit Special", "The reviews are in!", 180.0], {"comedy": 7}, -8.0, ["special_flop", "embarrassed", 1, "Special Flopped", "Crickets.", 150.0]], ["Use your old routine", 0.0, []]]],
	],
	"entertainer:1": [
		["Sold-Out Show", "Tonight's concert is sold out.", [["Play the new song", 16.0, ["encore", "inspired", 1, "Encore!", "They sang along!", 180.0], {"piano": 7}, -8.0, ["wrong_chord", "embarrassed", 1, "Wrong Chord", "Everyone heard it.", 150.0]], ["Stick to the hits", 0.0, []]]],
	],
	"writer:0": [
		["Book Tour", "Your publisher wants you on a book tour.", [["Give live readings", 16.0, ["adoring_fans", "confident", 1, "Adoring Fans", "Signed a hundred copies!", 180.0], {"writing": 7}, -8.0, ["tough_crowd", "sad", 1, "Tough Crowd", "Half the seats were empty.", 150.0]], ["Only sign books", 0.0, []]]],
	],
	"writer:1": [
		["Breaking Story", "A major story just broke and you're first on the scene.", [["Interview the witnesses", 16.0, ["scoop", "confident", 1, "Got the Scoop", "Front page!", 180.0], {"charisma": 7}, -8.0, ["misquote", "embarrassed", 1, "Misquoted", "A correction ran today.", 150.0]], ["Wait for the press release", 0.0, []]]],
	],
	"astronaut:0": [
		["Spacewalk", "The mission needs someone outside the station.", [["Volunteer for the spacewalk", 16.0, ["spacewalker", "confident", 1, "Spacewalker", "The view!", 180.0], {"logic": 7}, -8.0, ["space_sick", "uncomfortable", 1, "Space Sick", "Never again.", 150.0]], ["Stay inside", 0.0, []]]],
	],
	"astronaut:1": [
		["Cargo Inspection", "Space customs want to inspect your ship.", [["Bluff your way through", 16.0, ["slipped_through", "playful", 1, "Slipped Through", "Nothing to see here.", 180.0], {"fitness": 7}, -8.0, ["fined", "tense", 1, "Fined", "That was expensive.", 150.0]], ["Dump the cargo", 0.0, []]]],
	],
	"criminal:0": [
		["Turf War", "A rival crew is moving in on your territory.", [["Stand your ground", 16.0, ["respect", "confident", 1, "Respect", "Nobody messes with us.", 180.0], {"mischief": 7}, -8.0, ["lost_turf", "angry", 1, "Lost Turf", "They got the better of us.", 150.0]], ["Negotiate a truce", 0.0, []]]],
	],
	"criminal:1": [
		["Firewall", "Tonight's target has a brand-new firewall.", [["Hack straight through", 16.0, ["ghost_in_machine", "confident", 1, "Ghost in the Machine", "In and out.", 180.0], {"programming": 7}, -8.0, ["traced", "tense", 1, "Traced", "They almost found me.", 150.0]], ["Wait for another night", 0.0, []]]],
	],
	"secret_agent:0": [
		["Gala Infiltration", "You need to get into a gala full of suspects.", [["Charm the host for an invite", 16.0, ["inside", "confident", 1, "On the Inside", "Like a true agent.", 180.0], {"charisma": 7}, -8.0, ["thrown_out", "embarrassed", 1, "Thrown Out", "Not on the list.", 150.0]], ["Watch from outside", 0.0, []]]],
	],
	"secret_agent:1": [
		["Doomsday Device", "Your evil employer wants their doomsday device finished.", [["Sabotage a rival's plans first", 16.0, ["evil_laugh", "playful", 1, "Evil Laugh", "Mwahaha!", 180.0], {"mischief": 7}, -8.0, ["foiled", "angry", 1, "Foiled Again", "Curses!", 150.0]], ["Just keep building", 0.0, []]]],
	],
	"style_influencer:0": [
		["Red Carpet", "A celebrity client needs a look for tonight's red carpet.", [["Go bold", 16.0, ["best_dressed", "confident", 1, "Best Dressed", "Everyone's talking about it.", 180.0], {"charisma": 7}, -8.0, ["fashion_faux_pas", "embarrassed", 1, "Fashion Faux Pas", "Worst-dressed list.", 150.0]], ["Play it safe", 0.0, []]]],
	],
	"style_influencer:1": [
		["New Trend", "You could start a trend with your next post.", [["Post something daring", 16.0, ["trendsetter", "playful", 1, "Trendsetter", "Everyone's copying it!", 180.0], {"writing": 7}, -8.0, ["cringe", "embarrassed", 1, "Cringe", "That aged badly.", 150.0]], ["Post the usual", 0.0, []]]],
	],
}


## School counts as a "career" for children and teens: no pay, a grade instead.
const SCHOOLS: Array[String] = ["school", "high_school"]
const WORK_DAYS := 5
## Emotions that make a shift go better or worse.
const GOOD_MOODS: Array[String] = ["happy", "confident", "focused", "energized", "inspired"]
const BAD_MOODS: Array[String] = ["sad", "angry", "tense", "uncomfortable", "embarrassed", "bored"]


static func is_school(c: String) -> bool:
	return SCHOOLS.has(c)


## A school grade for a performance value.
static func grade(performance: float) -> String:
	if performance >= 80.0:
		return "A"
	if performance >= 60.0:
		return "B"
	if performance >= 40.0:
		return "C"
	if performance >= 20.0:
		return "D"
	return "F"


static func label(c: String) -> String:
	return INFO[c]["label"]


## Career branches, as in the reference: from level BRANCH_AT the Sim follows one
## of two paths, each with its own titles and pay for the top two levels.
## career -> [[branch label, [[title, pay], [title, pay]]], [...]]
const BRANCH_AT := 6
const BRANCHES := {
	"culinary": [["Chef", [["Head Chef", 56], ["Chef de Cuisine", 66], ["Restaurateur", 78], ["Celebrity Chef", 92]]], ["Mixologist", [["Bartender", 52], ["Head Bartender", 62], ["Cocktail Artist", 74], ["Master Mixologist", 88]]]],
	"tech": [["Start-up Entrepreneur", [["Start-up Founder", 66], ["Funded Founder", 80], ["Tech Visionary", 96], ["Tech Mogul", 115]]], ["eSport Gamer", [["Pro Gamer", 60], ["Team Player", 72], ["eSport Champion", 88], ["eSport Legend", 105]]]],
	"painter": [["Master of the Real", [["Gallery Painter", 54], ["Portraitist", 64], ["Renowned Realist", 78], ["Master Painter", 94]]], ["Patron of the Arts", [["Art Dealer", 56], ["Curator", 68], ["Gallery Owner", 82], ["Patron of the Arts", 100]]]],
	"business": [["Management", [["Executive", 66], ["Senior Executive", 80], ["COO", 98], ["Business Tycoon", 120]]], ["Investor", [["Investor", 64], ["Venture Capitalist", 78], ["Fund Manager", 95], ["Angel Investor", 116]]]],
	"athlete": [["Bodybuilder", [["Fitness Model", 58], ["Fitness Champion", 70], ["Pro Bodybuilder", 84], ["Mr. or Ms. Galaxy", 100]]], ["Professional Athlete", [["All-Star", 62], ["MVP", 76], ["Living Legend", 94], ["Hall of Famer", 115]]]],
	"entertainer": [["Comedian", [["Comic", 54], ["Comedy Headliner", 66], ["Comedy Star", 82], ["Comedy Legend", 100]]], ["Musician", [["Session Musician", 56], ["Virtuoso", 68], ["Rock Star", 85], ["Musical Superstar", 104]]]],
	"writer": [["Author", [["Novelist", 56], ["Bestselling Author", 70], ["Prize Winner", 86], ["Literary Legend", 105]]], ["Journalist", [["Reporter", 54], ["Columnist", 66], ["Senior Editor", 80], ["Editor-in-Chief", 98]]]],
	"astronaut": [["Space Ranger", [["Commander", 66], ["Space Explorer", 80], ["Galactic Pioneer", 98], ["Space Ranger", 120]]], ["Interstellar Smuggler", [["Space Hustler", 62], ["Space Pirate", 76], ["Smuggler Captain", 94], ["Interstellar Smuggler", 115]]]],
	"criminal": [["Boss", [["Henchman", 60], ["Underboss", 74], ["Crime Boss", 92], ["Criminal Mastermind", 112]]], ["Oracle", [["Hacker", 62], ["Cyber Thief", 76], ["Digital Ghost", 94], ["Oracle", 115]]]],
	"secret_agent": [["Diamond Agent", [["Double-O Agent", 66], ["Elite Agent", 80], ["Super Agent", 98], ["Diamond Agent", 120]]], ["Villain", [["Henchman", 56], ["Evil Lieutenant", 70], ["Villainous Mastermind", 88], ["Supervillain", 110]]]],
	"style_influencer": [["Stylist", [["Personal Stylist", 56], ["Celebrity Stylist", 68], ["Style Guru", 84], ["Style Icon", 102]]], ["Trend Setter", [["Influencer", 58], ["Trendsetter", 70], ["Fashion Authority", 86], ["Fashion Mogul", 105]]]],
}


## The skill each branch leans on, as in the reference (the career's own skill
## until the branch point). career -> [branch 0 skill, branch 1 skill]
const BRANCH_SKILLS := {
	"culinary": ["cooking", "mixology"],
	"tech": ["programming", "gaming"],
	"painter": ["painting", "charisma"],
	"business": ["charisma", "logic"],
	"athlete": ["fitness", "fitness"],
	"entertainer": ["comedy", "piano"],
	"writer": ["writing", "charisma"],
	"astronaut": ["logic", "fitness"],
	"criminal": ["mischief", "programming"],
	"secret_agent": ["charisma", "mischief"],
	"style_influencer": ["charisma", "writing"],
}


## The skill that counts for promotion to `level` (and for performance there).
static func skill_for(c: String, level: int, branch: int) -> String:
	if level >= BRANCH_AT and branch >= 0 and BRANCH_SKILLS.has(c):
		return BRANCH_SKILLS[c][clampi(branch, 0, 1)]
	return INFO[c]["skill"]


## Work uniforms, as in the reference: [shirt, trousers, long sleeves].
const UNIFORMS := {
	"culinary": [Color(0.97, 0.97, 0.95), Color(0.15, 0.15, 0.17), true],
	"tech": [Color(0.3, 0.32, 0.36), Color(0.2, 0.25, 0.4), false],
	"painter": [Color(0.9, 0.82, 0.62), Color(0.35, 0.3, 0.25), true],
	"business": [Color(0.18, 0.2, 0.3), Color(0.18, 0.2, 0.3), true],
	"athlete": [Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.95), false],
	"entertainer": [Color(0.55, 0.15, 0.6), Color(0.1, 0.1, 0.12), true],
	"writer": [Color(0.6, 0.45, 0.32), Color(0.3, 0.28, 0.25), true],
	"astronaut": [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), true],
	"criminal": [Color(0.1, 0.1, 0.12), Color(0.1, 0.1, 0.12), true],
	"secret_agent": [Color(0.08, 0.08, 0.1), Color(0.08, 0.08, 0.1), true],
	"style_influencer": [Color(0.95, 0.5, 0.65), Color(0.95, 0.9, 0.8), false],
}


static func has_branches(c: String) -> bool:
	return BRANCHES.has(c)


static func branch_labels(c: String) -> Array:
	return BRANCHES.get(c, []).map(func(b): return b[0])


static func _level_entry(c: String, level: int, branch: int) -> Array:
	if level >= BRANCH_AT and BRANCHES.has(c):
		var b: Array = BRANCHES[c][clampi(branch, 0, 1)]
		return b[1][mini(level - BRANCH_AT, b[1].size() - 1)]
	return INFO[c]["levels"][level]


static func title(c: String, level: int, branch := 0) -> String:
	return _level_entry(c, level, branch)[0]


static func hourly(c: String, level: int, branch := 0) -> int:
	return _level_entry(c, level, branch)[1]


static func max_level(c: String) -> int:
	if BRANCHES.has(c):
		return BRANCH_AT + (BRANCHES[c][0][1] as Array).size() - 1
	return INFO[c]["levels"].size() - 1


static func shift_hours(c: String) -> int:
	return posmod(INFO[c]["end"] - INFO[c]["start"], 24)


## Whether hour `h` is inside the shift (night shifts wrap past midnight).
static func on_shift(c: String, h: int) -> bool:
	var s: int = INFO[c]["start"]
	var e: int = INFO[c]["end"]
	return (h >= s and h < e) if s < e else (h >= s or h < e)


## Skill level needed to be promoted from `level` to the next one.
## Ten levels, as in the reference: the career skill must keep pace with the job.
static func skill_for_promotion(level: int) -> int:
	return clampi(level + 1, 1, 10)


static func is_work_day(day: int) -> bool:
	return (day - 1) % 7 < WORK_DAYS


static func schedule_text(c: String) -> String:
	return "Mon–Fri  %s – %s" % [_hour(INFO[c]["start"]), _hour(INFO[c]["end"])]


static func _hour(h: int) -> String:
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d %s" % [h12, "AM" if h < 12 else "PM"]


## Performance gained in one shift (0..100 scale) for a mood and skill level.
static func shift_performance(mood: String, skill_level: int) -> float:
	var base := 18.0
	if GOOD_MOODS.has(mood):
		base = 28.0
	elif BAD_MOODS.has(mood):
		base = 8.0
	return base + skill_level * 1.5
