#!/usr/bin/env python3
"""Build the Ask Pattie decision tree.

Three deterministic steps: what you're training for, what's bothering you, here
is what Pattie has already said about it. No model in the loop at runtime, which
is the whole point. It costs nothing per question, it can only ever surface
advice she actually gave on camera, and it answers on a start line with no
signal.

Every answer paraphrases one of her episodes and carries the audio cut from that
episode by `cut-pattie-voice.py`, so the app is routing to her rather than
speaking for her.

**This script refuses to write a tree with a dead end.** Every (goal, topic) pair
a thumb can reach has to land on at least one answer; every answer has to name a
real pointer and a real solution clip; and no answer may claim a goal whose topic
list does not include its topic. That last one is the failure you cannot spot by
reading the JSON: the answer exists, it is simply unreachable.

Writes `docs/ask-pattie.json` (hot-loaded) and `IronSplits/Resources/ask-pattie.json`
(the bundled offline fallback). Run it instead of hand-editing either file.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIPS = json.load(open(os.path.join(ROOT, "docs", "pattie-voice.json")))["clips"]
POINTERS = {p["id"] for p in json.load(open(os.path.join(ROOT, "docs", "pointers.json")))["pointers"]}


def clip(kind, episode):
    """Bundle resource name for a cut clip, or None if that one was never cut."""
    name = f"pattie-{kind}-{episode}"
    return name if name in CLIPS else None


# id, title, subtitle, SF Symbol, topic ids in the order they are offered
GOALS = [
 ("first-tri", "My first triathlon",
  "Everything is new and the transition area is the scary part.", "figure.mixed.cardio",
  ["race-morning", "swim-start", "swim-gear", "transitions", "bike-handling", "weather", "feet", "after"]),
 ("sprint-oly", "A sprint or olympic",
  "Short and fast, so nothing you fumble comes back.", "stopwatch",
  ["race-morning", "swim-start", "swim-gear", "transitions", "bike-handling", "bike-trouble",
   "fuel", "feet", "weather", "after"]),
 ("half", "A 70.3",
  "Long enough that the small stuff compounds.", "figure.open.water.swim",
  ["race-morning", "swim-start", "swim-gear", "transitions", "bike-handling", "bike-trouble",
   "fuel", "run-form", "feet", "weather", "after"]),
 ("full", "A full distance",
  "A day long enough for every one of these to matter.", "flag.checkered",
  ["race-morning", "swim-start", "swim-gear", "transitions", "bike-handling", "bike-trouble",
   "fuel", "run-form", "feet", "weather", "after"]),
 ("run-race", "A marathon or run race",
  "No swim, no bike, and your feet carry the whole day.", "figure.run",
  ["race-morning", "run-form", "feet", "fuel", "weather", "after"]),
 ("open-water", "Open water swimming",
  "Training swims, swim buddies, and getting back to the car.", "water.waves",
  ["swim-start", "swim-gear", "weather", "after"]),
]

# id, title, SF Symbol, the second question worded for this topic
TOPICS = [
 ("race-morning", "Race morning", "sunrise.fill", "What is race morning throwing at you?"),
 ("swim-start", "The swim start", "figure.open.water.swim", "What happens in the water?"),
 ("swim-gear", "Wetsuits, caps and gear", "bag.fill", "Which bit of the swim kit?"),
 ("transitions", "Transitions", "arrow.triangle.2.circlepath", "Which transition?"),
 ("bike-handling", "Riding and handling", "bicycle", "What is happening on the bike?"),
 ("bike-trouble", "When the bike goes wrong", "wrench.and.screwdriver.fill", "What went wrong?"),
 ("fuel", "Fuel and hydration", "drop.fill", "What about fuelling?"),
 ("run-form", "Running form and effort", "figure.run", "What about the run?"),
 ("feet", "Feet, shoes and blisters", "shoeprints.fill", "What is going on down there?"),
 ("weather", "Cold, rain and wind", "cloud.rain.fill", "What is the weather doing?"),
 ("after", "After the finish", "medal.fill", "What happens after?"),
]

# id, topic, goals, headline, her situation, her solution, episode number
ANSWERS = [
 ("morning-backpack", "race-morning", ["first-tri", "sprint-oly", "half", "full"],
  "Carry one bag, not six",
  "It's race day morning and you have a backpack full of transition bags, fuel bottles and special needs bags. It's heavy.",
  "Use one backpack instead of carrying all those separate bags, because you're going to drop them everywhere. Then the neat part: once your bike is set up in T1, take out the wetsuit, cap, goggles and morning clothes bag, roll the backpack into a tight ball and stick it in your morning clothes bag. After the race you pull it back out, and everything, empty bottles, food, your medal, goes in one bag.", "03"),
 ("morning-flipflops", "race-morning", ["first-tri", "sprint-oly", "half", "full"],
  "98 cent flip flops to the swim start",
  "It's race day morning and you're walking down to the swim start, over a boat ramp or sand, and you want shoes. But you're not getting them back.",
  "Get yourself some 98 cent flip flops from Walmart to walk down in. Take them off right before you enter the water and throw them in the receptacle. Nothing to feel bad about.", "12"),
 ("morning-tyvek", "race-morning", ["first-tri", "sprint-oly", "half", "full", "run-race"],
  "Staying warm in the start corral",
  "It's race morning, it's cold, it's raining, and you're standing around in the crowd for hours before anything starts.",
  "Get one of those Breaking Bad Tyvek suits. It keeps you warm, the rain doesn't get in and it doesn't breathe, so you're toasty while you wait.", "04"),

 ("swim-contact", "swim-start", ["first-tri", "sprint-oly", "half", "full", "open-water"],
  "It's a contact sport, and none of it is personal",
  "You're in the swim, it's crowded, and you're getting hit. Someone's hitting your head, you're hitting someone's legs. It's an uncomfortable feeling.",
  "Understand that nobody is hitting you on purpose. Once you know that, veer off a couple of inches to the left or to the right, and the water is nice and clear again.", "13"),
 ("swim-bright-cap", "swim-start", ["open-water", "first-tri", "sprint-oly", "half", "full"],
  "Wear a bright cap so people can find you",
  "You're out swimming with your buddies and somebody has a dark cap on. When your eyes are level with the water and it's choppy, you cannot see her at all.",
  "Wear a bright coloured cap in open water so people can see you. Races sometimes hand out dark caps, but they also have kayakers, lifeguards and safety protocols watching everybody. On a training swim you have none of that, so the cap is the whole system.", "15"),
 ("swim-key", "swim-start", ["open-water", "first-tri"],
  "The car key problem",
  "It's a beautiful day for an ocean swim, all your belongings are in the car, and you have nowhere to put the key.",
  "Take the mechanical key out of the fob, pin it to your swimsuit or trunks with a safety pin so it sits inside your wetsuit, and go swim. You won't lose it and nothing gets taken. We all know what wetsuits cost in this sport.", "18"),

 ("gear-wetsuit-roll", "swim-gear", ["first-tri", "sprint-oly", "half", "full", "open-water"],
  "Roll the wetsuit like a sausage",
  "You're heading out to a swim or about to start your race, and the wetsuit is a pain to keep together.",
  "Lay it out flat, fold up the legs, fold up the arms, roll it into a sausage and put two elastic strips around it. Bonus: keep the bag that fold-up chairs come in and carry the rolled wetsuit in that, over your shoulder.", "10"),
 ("gear-cap-stick", "swim-gear", ["open-water", "first-tri", "sprint-oly", "half", "full"],
  "Stop your swim caps melting together",
  "It's summer, you pull your swim caps out of the closet, and they've stuck together and rip apart when you separate them.",
  "Before you store them, put baby powder inside each cap and between them. They won't stick, and you get to use whichever cap you want.", "11"),

 ("t1-mud", "transitions", ["first-tri", "sprint-oly", "half", "full"],
  "Mud in your cleats",
  "It's been raining, the transition area is grass, and it's full of mud. You walk your bike through it and your cleat is packed. There's no way you're clipping in.",
  "Get the booties they hand out when your carpets get cleaned and put them over your bike shoes. Walk through transition, cleats stay clean, and when you're ready to mount you take them off and hand them to a volunteer.", "01"),
 ("t1-freezer-bag", "transitions", ["sprint-oly", "half", "full", "first-tri"],
  "A freezer bag down the front",
  "You've come out of the swim, you're exiting T1, and there's a steep descent or it's just chilly.",
  "Put a gallon freezer bag down your chest. It keeps the wind off while you descend, and once you warm up you pull it out and away you go. Don't do what I did at Santa Rosa and realise at mile 90 that it's still in there.", "06"),
 ("t2-lube", "transitions", ["half", "full", "sprint-oly", "first-tri"],
  "Lube your toes in T2 without the mess",
  "You're about to run off the bike and your toes are going to blister.",
  "Put your lubricant in a baggie, turn the baggie inside out over your hand and use it as a glove. Get it all over your toes, then fold the baggie back up and put it in your pocket. You can do exactly this in transition.", "19"),

 ("bike-bubs", "bike-handling", ["first-tri", "sprint-oly", "half", "full"],
  "B.U.B.S., so you never have a zero mile per hour fall",
  "You've got your first set of bike shoes and pedals. Clipping in is easy. Clipping out is not, especially out on the open road.",
  "Remember Bubs. Brake. Unclip. Butt off the seat. Stand, by putting your foot down. Approaching a stop sign you brake, unclip, get your butt off the seat, and stand so you're completely off the bike by the time you get there. Say it out loud and practise it, so you never get one of those zero mile per hour falls and the bloody knees that come with it.", "16"),
 ("bike-climb", "bike-handling", ["sprint-oly", "half", "full"],
  "Climbing on a tri bike",
  "You're about to climb, and a triathlon bike is not the easiest thing to climb hills with.",
  "Sit up. Chin horizontal with the horizon so you can get as much air in and out as possible. Put your hands on the elbow pads to keep the airway open, sit your butt as far back on the saddle as you can to get the most out of your legs, and keep climbing. And when you crest it: no resting. Your heart rate comes down while you keep pedalling.", "09"),
 ("bike-left-hand", "bike-handling", ["half", "full"],
  "Practise the left-hand grab",
  "You're racing somewhere they ride on the left, so the aid stations are on the left and you cannot grab a bottle with your right hand.",
  "Practise. Grabbing behind with your left hand, getting the bottle out of the cage, opening the front, pouring in, squeezing the bottle, closing it against your rib cage, reaching around and finding the cage again. You can do all of it on the trainer. Practise, practise, practise.", "08"),

 ("flat-helmet", "bike-trouble", ["sprint-oly", "half", "full"],
  "Your helmet is the parts tray",
  "You've got a flat, you're on the side of the road, and every car that goes by throws your components across the road.",
  "Take your helmet off, helmet hair and all, and put every component into it. Everything stays tucked together while you work, no matter what the breeze does.", "07"),
 ("flat-wind", "bike-trouble", ["sprint-oly", "half", "full"],
  "Anything you put down outside will move",
  "It's breezy and you're trying to work on the bike at the roadside.",
  "Contain it before you start. The helmet holds every part of a flat repair. The same rule applies at an aid station: a baggie narrower than the bottle mouth keeps your powder out of the wind.", "05"),

 ("fuel-baggie", "fuel", ["sprint-oly", "half", "full", "run-race"],
  "The right size baggie for powder",
  "It's windy, you're on a long ride or at an aid station, and you're pouring powder into a bottle out of a bag that's wider than the bottle mouth. It goes everywhere.",
  "Use a small rectangular bag, the kind you can get from Uline. The mouth of the baggie has to fit inside the mouth of the bottle. Shove it in and pour. No powder over you, the volunteers, or your bike.", "05"),
 ("fuel-weak-hand", "fuel", ["half", "full"],
  "Getting fluid in when the aid station is on the wrong side",
  "The bottles are coming at you from the side you don't use.",
  "It's a skill, not a strength problem. Practise the whole sequence on the trainer, bottle out, open, pour, squeeze, close, replace, until your weak hand can do it without you looking down.", "08"),
 ("fuel-run-carry", "fuel", ["run-race"],
  "Carrying what you need on a long run",
  "You want your lubricant, your fuel and your phone with you, and no good way to carry any of it.",
  "A baggie does more than one job. It's a glove for putting lubricant on, then it folds up small and goes in a pocket. Small and rectangular beats big and floppy every time.", "19"),

 ("run-arms", "run-form", ["half", "full", "run-race"],
  "Stop spending energy sideways",
  "You're out for a long run and you want to be as efficient as you can be.",
  "Use your arms forward, not side to side. You've seen those people. Thumbs going towards your ears, elbows in towards your hips. And don't grip. Keep your hands loose like you're holding a soft boiled egg, not tight enough to break it. That's energy you get to spend on the finish line instead.", "20"),
 ("run-recover-moving", "run-form", ["half", "full", "run-race"],
  "Recover while you're still moving",
  "You've just finished something hard and everything says stop.",
  "No resting. Let your heart rate come down while you keep pedalling, or keep running. The finish line is somewhere out there on the horizon.", "09"),

 ("feet-tongue", "feet", ["run-race", "half", "full", "first-tri", "sprint-oly"],
  "Shoe tongue that will not stay put",
  "You're out on a training run and it feels like there's a rock in your shoe. What's actually happened is the tongue has slipped sideways and gone crooked.",
  "Take the shoelace, come around and go over then under from the opposite side, through the little cutout in the tongue. That keeps the tongue centred. Then finish lacing normally, and you won't be tongue tied.", "17"),
 ("feet-blisters", "feet", ["run-race", "half", "full", "first-tri", "sprint-oly"],
  "Blisters on your toes",
  "You're doing long runs and your toes keep blistering.",
  "Two options. Get a pedicure and cover the toenails so you can't see they're black and blue. Or lubricate: put the lubricant in a baggie, go inside out and use the baggie as a glove, and get it all over your toes. Fold the baggie up, pocket it, and go. No more bandages.", "19"),

 ("cold-tyvek", "weather", ["first-tri", "sprint-oly", "half", "full", "run-race", "open-water"],
  "Standing around in the cold and rain",
  "It's race morning, or a freezing training morning, and you're standing around for hours. It's cold and it's raining.",
  "Get one of those Breaking Bad Tyvek suits. It keeps you warm, the rain doesn't get in and it doesn't breathe, so you're toasty while you wait in the crowd.", "04"),
 ("cold-gloves", "weather", ["run-race", "half", "full", "first-tri", "sprint-oly", "open-water"],
  "Hands that won't warm up",
  "It's raining, you're waiting for the start, and your hands are cold.",
  "Surgical gloves over your regular gloves. Once you're running and your hands warm up, pull the surgical gloves off and bin them, and carry on racing feeling great.", "04"),
 ("cold-descent", "weather", ["sprint-oly", "half", "full", "open-water"],
  "Chilled coming out of the water",
  "You're wet, and the first thing after the swim is wind.",
  "A gallon freezer bag down the front of your chest takes the wind off until you warm up. Then it comes straight out and away you go.", "06"),

 ("after-phone", "after", ["first-tri", "sprint-oly", "half", "full", "run-race"],
  "You finished and you don't have your phone",
  "You've just finished, you're exhausted, you've got your medal and your morning clothes bag, and no phone. What's the number of the friend who dropped you off? No clue.",
  "Before you put your shoes in your T2 bag, write your friend's number on your shoe. Then you can hand it to a stranger and ask them to call. People at a finish line are always willing to help.", "02"),
 ("after-backpack", "after", ["first-tri", "sprint-oly", "half", "full"],
  "Getting everything home",
  "The race is over and you have bottles, wrappers, wet kit and a medal to carry.",
  "This is why the backpack went into your morning clothes bag. Pull it back out and everything goes in one bag instead of five.", "03"),
 ("after-swim-kit", "after", ["open-water", "run-race"],
  "Packing up a wet session",
  "You're done, you're wet, and everything has to go back in the car.",
  "Roll the wetsuit flat, fold the legs and arms in, roll it into a sausage with two elastic strips, and put it in the bag your fold-up chair came in. It goes over your shoulder and your boot stays dry.", "10"),
]


def build():
    answers = [{
        "id": aid, "topic": topic, "goals": goals,
        "headline": headline, "situation": situation, "solution": solution,
        "pointerID": f"ep-{episode}",
        "situationVoice": clip("hook", episode),
        "solutionVoice": clip("solution", episode),
        "signoffVoice": clip("signoff", episode),
    } for aid, topic, goals, headline, situation, solution, episode in ANSWERS]

    topic_ids = {t[0] for t in TOPICS}
    goal_ids = {g[0] for g in GOALS}
    goal_topics = {g[0]: g[4] for g in GOALS}

    errors = []
    for answer in answers:
        if answer["topic"] not in topic_ids:
            errors.append(f"{answer['id']}: unknown topic {answer['topic']}")
        if answer["pointerID"] not in POINTERS:
            errors.append(f"{answer['id']}: unknown pointer {answer['pointerID']}")
        if not answer["solutionVoice"]:
            errors.append(f"{answer['id']}: no solution audio for {answer['pointerID']}")
        for goal in answer["goals"]:
            if goal not in goal_ids:
                errors.append(f"{answer['id']}: unknown goal {goal}")
            elif answer["topic"] not in goal_topics[goal]:
                errors.append(f"{answer['id']}: topic {answer['topic']} is unreachable from {goal}")
    for goal, title, _, _, topics in GOALS:
        for topic in topics:
            if topic not in topic_ids:
                errors.append(f"goal {goal}: unknown topic {topic}")
            elif not any(a["topic"] == topic and goal in a["goals"] for a in answers):
                errors.append(f"dead end: {goal} / {topic} has no answers")
    if errors:
        print("REFUSING TO WRITE, the tree has holes:", file=sys.stderr)
        for error in errors:
            print("  " + error, file=sys.stderr)
        sys.exit(1)

    return {
        "version": 1,
        "title": "Ask Pattie",
        "subtitle": "Tell her what you're training for and what's bothering you. "
                    "Every answer is one of her own pointers, in her own voice.",
        "goalQuestion": "What are you training for?",
        "goals": [{"id": g[0], "title": g[1], "subtitle": g[2], "symbol": g[3], "topics": g[4]}
                  for g in GOALS],
        "topics": [{"id": t[0], "title": t[1], "symbol": t[2], "question": t[3]} for t in TOPICS],
        "answers": answers,
    }


if __name__ == "__main__":
    guide = build()
    hosted = os.path.join(ROOT, "docs", "ask-pattie.json")
    bundled = os.path.join(ROOT, "IronSplits", "Resources", "ask-pattie.json")
    with open(hosted, "w") as handle:
        json.dump(guide, handle, indent=2, ensure_ascii=False)
    shutil.copyfile(hosted, bundled)
    print(f"{len(guide['goals'])} goals, {len(guide['topics'])} topics, "
          f"{len(guide['answers'])} answers, no dead ends")
    for goal in guide["goals"]:
        reachable = sum(1 for a in guide["answers"] if goal["id"] in a["goals"])
        print(f"  {goal['id']:11s} {len(goal['topics']):2d} topics, {reachable:2d} answers")
