---
title: "Dev Diary - Entry #3"
date: 2026-05-15T15:09:54+02:00
featureImage: https://media.lemon.industries/pokemon-oop-christopher-okhravi.jpg
draft: false
description: "A dev diary entry where I talk about a new project about implementing a DSL in Rust for modeling Pokémon battles."
summary: "A 1am YouTube recommendation lead me down a rabbit hole of creating my own DSL for modeling Pokémon battles in Rust."
categories: ["Poké DSL"]
tags: ["rust", "pokémon", "dsl"]
---

Yep, I started a new project. I SWEAR I will continue with File Valet another day. Hear me out! >:)

## Inspiration

Yesterday (well technically today) at 1am, Youtube recommended me a video by Christopher Okhravi (a friend recommended me in the past already, I already enjoyed the idea back then but never went through with trying it out). Its about building an object-oriented representation of Pokémon battles. While the battles themselves seem simple on the surface, the logic behind them can get incredibly convoluted. 

The goal of that video was to show how one can build useful abstractions of the whole battle system and thus create a kind of Domain Specific Language (DSL) from it. In Java or other object-oriented languages (which the video mainly focuses on) you use Interfaces and nest Objects within each other to achieve a DSL. In Rust we can do it similarly by nesting enums inside of each other (we actually wont need that many traits here), and that realization was what ultimately lead me to trying all of this out myself (and I had to go to sleep, fully hyped to tackle this on, at 2am...).

If youre interested you can watch it right here or skip ahead to the next section c:

{{< youtubeLite id="CyRtTwKeulE" label="Rebuilding Pokémon with Object Oriented Programming" >}}

---

## What exactly is a DSL?
Domain specific languages are small languages made to express concepts within a certain sphere of problems. Opposite to general-purpose languages like Rust or Java, which can literally express *anything*, DSLs often focus on smaller areas. A well-designed DSL lets you model all problems in your problem space through combinations of symbols of that language, and it might even make the described problems as readable as if it would have been expressed through natural language.

We are already using DSLs everywhere. SQL is a DSL for querying data, regex for pattern matching, HTML for document structure. None of them are general-purpose, but can be interpreted by programs to solve the described problem: finding specific data in database, finding the specified pattern in a string or rendering the described HTML page in a browser window. 

When it comes to Pokémon battles, the DSL will need to be able to express who is fighting against each other, what moves they can choose and what they do or what abilities they have and what changes they might inflict on the battle, and much more. So that we can eventually build moves and their effects, and everything else thats relevant to a battle, in our own little language without touching the game logic itself.

---

## Creating a Pokémon DSL in Rust

In the video Christopher modeled everything top-to-bottom, starting at the top with the most general thing we want to model. While this might make us introduce types that we did not define yet early on, I think it is a nice approach to slowly explore the scope of everything. (For some reason I usually go bottom-to-top... "o.o). I simplified the following code examples (stripping away how exactly the data is fetched or modeled, the core concepts stay the same. If youre interested how it currently looks like, you can scroll all the way down where I linked the repository).

### The battle

The most general thing we want to model is the battle itself:
```rs
pub struct Battle {
    fighters: Vec<Fighter>,
    ..
}
```
Its literally just a collection of fighters which are gonna fight each other. We do not care who is who or who can attack whom yet.

The fighters are of some species which contains a name, types, stats, etc. They have some set of moves they are allowed to use in this battle and also a team id (for identifying who is to attack whom). In reality, same with the battle state, this will grow alot once you model the whole battle system.
```rs
pub struct Fighter {
    species: Species,
    moves: Vec<Move>,
    team: usize,
    ..
}
```

The moves are where it gets actually interesting. A move has a certain condition at which it is able to be executed, and once executed, it tries to do *something*, which is called an attempt. (Depending on the final model, you might actually want to have more than one condition, Christopher explained it in his video but I simplified it here).
```rs
pub struct Move {
    name: String,
    types: Vec<PokemonType>,
    condition: BattleCondition,
    attempt: Attempt,
    ..
}
```

### Conditions

Before we talk about the attempt I want to talk about conditions, which were a bit more complex to model than in the video. I have decided to go for a tree-like structure where the leafs are predicates that can always be evaluated in a certain context.
```rs
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum Condition<L> {
    Always,
    And(Box<Condition<L>>, Box<Condition<L>>),
    Or(Box<Condition<L>>, Box<Condition<L>>),
    Not(Box<Condition<L>>),
    Predicate(L),
}
```

To know in *which* context a leaf is to be evaluated, an `L` of a condition will need to implement checkable. It just checks that some condition on the context is either true or false.
```rs
pub trait Checkable {
    type Context;
    fn check(&self, ctx: &mut Self::Context) -> bool;
}
```

We can then implement a function `check` on our condition thats available whenever it has a leaf-type that implements `Checkable`. If we pass the proper context the leaf-type of a certain condition expects, we can evaluate it.
```rs
impl<L: Checkable> Condition<L> {
    pub fn check(&self, ctx: &mut L::Context) -> bool {
        match self {
            Condition::Always => true,
            Condition::And(a, b) => a.check(ctx) && b.check(ctx),
            Condition::Or(a, b) => a.check(ctx) || b.check(ctx),
            Condition::Not(a) => !a.check(ctx),
            Condition::Predicate(p) => p.check(ctx),
        }
    }
}
```

To make the conditions a usable part of our Pokémon battle DSL we will need to be able to check certain conditions given the current battle as context. For this I created a new leaf-type (or predicate) specifically for checking battle conditions.
```rs
pub enum BattlePredicate {
    HasFieldEffect(FieldEffect),
    Prob(Probability),
    Target {
        target: Target,
        cond: FighterCondition,
    },
    ..
}

impl Checkable for BattlePredicate {
    type Context = Battle;
    fn check(&self, battle: &mut Battle) -> bool {
        match self {
            BattlePredicate::HasFieldEffect(effect) => battle.has_field_effect(effect),
            BattlePredicate::Prob(p) => p.roll(battle.rng()),
            BattlePredicate::Target { target, cond } => {
                let fighter = target.resolve(battle);
                cond.check(&fighter)
            },
        }
    }
}
```
Thanks to the `Target` predicate we are able to go even deeper and create conditions specific to one fighter of the current battle.

```rs
pub enum FighterPredicate {
    HasStatusEffect(StatusEffect),
    IsMaxHp,
    ..
}

impl Checkable for FighterPredicate {
    type Context = Fighter;

    fn check(&self, fighter: &mut Self::Context) -> bool {
        match self {
            Self::HasStatusEffect(effect) => fighter.has_status_effect(effect),
            Self::IsMaxHp => fighter.current_hp() == fighter.max_hp(),
        }
    }
}
```

### Example conditions
Dream eater can only be used if a target is asleep:
```rs
Predicate(Target(Opponent, Predicate(HasStatusEffect(Sleep))))
```

When trying to use rest, the user must not be at max HP:
```rs
BattleCondition::Not(BattleCondition::Predicate(BattlePredicate::Target(
    Target::User,
    FighterCondition::Predicate(FighterPredicate::IsMaxHp),
)))
```

Thunder during rain has 100% accuracy, so an accuracy check might look like this:
```rs
BattleCondition::Or(
    BattleCondition::Predicate(BattlePredicate::HasFieldEffect(FieldEffect::Rain)),
    BattleCondition::Predicate(BattlePredicate::Prob(0.7)),
)
```

Facade has double the power if the user is burned, poisoned or paralyzed:
```rs
BattleCondition::Or(
    BattleCondition::Predicate(BattlePredicate::Target(
        Target::User,
        FighterCondition::Predicate(FighterPredicate::HasStatusEffect(StatusEffect::Burn)),
    )),
    BattleCondition::Or(
        BattleCondition::Predicate(BattlePredicate::Target(
            Target::User,
            FighterCondition::Predicate(FighterPredicate::HasStatusEffect(StatusEffect::Poison)),
        )),
        BattleCondition::Predicate(BattlePredicate::Target(
            Target::User,
            FighterCondition::Predicate(FighterPredicate::HasStatusEffect(StatusEffect::Paralysis)),
        )),
    ),
)
```

This might look convoluted now, but when we eventually serialize it as .ron (Rust Object Notation), it will become a bit neater. For example with facade:
```rs
Or(
    Predicate(Target(User, Predicate(HasStatusEffect(Burn)))),
    Or(
        Predicate(Target(User, Predicate(HasStatusEffect(Poison)))),
        Predicate(Target(User, Predicate(HasStatusEffect(Paralysis)))),
    ),
)
```

### Attempts

An attempt is the intent of a Pokémons move to do *something*:
```rs
pub struct Move {
    name: String,
    types: Vec<PokemonType>,
    condition: BattleCondition,
    attempt: Attempt,
    ..
}
```

And we are able to roughly model it like this:
```rs
pub enum Attempt {
    Attempt {
        condition: BattleCondition,
        success: Effect,
        failure: Effect,
        after: Effect,
    },
    Cascade {
        attempts: Vec<Attempt>,
    },
    Combo {
        condition: BattleCondition,
        hits: Number,
        effect: Effect,
    },
    ..
}
```
They are essentially just different ways of combining effects. `Attempt` (the enum value) itself is just a check on a `BattleCondition` which will then execute certain effects depending on the outcome of the condition. `Cascade` on the other hand wraps multiple consecutive attempts, where the failure of one will mark the end of the chain, the following attempts will be skipped. `Combo` can be used to just execute an effect x amount of times without any individual of them being able to fail mid-chain.

`Number` is yet another type that can be evaluated on the battle state and returns a number. It might return a different number depending on certain conditions, just a random number in a specific range, or an exact number thats always the same. This type might grow and look very different depending on how the modeling of the rest of the battle system will turn out in the end. For now, it gives us more flexibility in defining conditional numbers within our DSL.
```rs
pub enum Number {
    Exact(usize),
    ..
}

impl Number {
    pub fn evaluate(&self, battle: &Battle) -> usize {
        match self {
            Number::Exact(n) => *n,
        }
    }
}
```

### Effects

An effect is something that mutates the battle in a specific way. It might depend on a condition or could even be chained into a sequence of different effects. The concrete effects could just be about dealing a specific amount of damage to a target, or to apply a status condition. Though (and you know if youve played Pokémon), those effects can grow quite complex.

```rs
pub enum Effect {
    None,
    Condition {
        cond: BattleCondition,
        success: Box<Effect>,
        failure: Box<Effect>,
    },
    Sequence {
        effects: Vec<Effect>,
    },
    DirectDamage {
        target: Target,
        amount: Number,
    },
    OHKO(Target), // One-hit K.O.
    ..
}

impl Effect {
    pub fn apply(&self, battle: &mut Battle) {
        ..
    }
}
```
I do not yet know which moves might require me to do which refactorings. But what I know for now is that it might be helpful to find common denominators of more complex effects, like atomic buildings blocks. That would make the DSL more powerful and also make complex effects easier to understand. The overall approach might have to be re-evaluated depending on the effects to be added though.

### Abilities & Held Items

The current approach only allows us to describe what move execution entails, what a move tries to do and which effects it might have on the battle. To model abilities or held items we need something that can also act passively, like the oran berry that heals its user but only when its HP reaches a certain threshold.

To achieve this, I am gonna reuse the effects that change something within the battle, but pair it with a trigger. Anywhere in our engine that ultimately solves our DSL can we call `battle.trigger(Trigger)` which will then evaluate abilities and held items for their `TriggerEffect`s. If the trigger is the same as the one currently triggered, the effect will be executed.
```rs
pub enum Trigger {
    TurnStart,
    TurnEnd,
    DamageDealt(Target),
}


pub struct TriggerEffect {
    trigger: Trigger,
    effect: Effect,
}
```

An ability would look like this. `Intimidation` for example could have a trigger like `Trigger::SwitchIn` and an effect of lowering all opponents HP. While other abilities might trigger at the start of every turn and influence damage calculation with its effect. The expressiveness of this system will solely rely on how well we place our triggers and how expressive our effects system already is.
```rs
pub struct Ability {
    name: String,
    triggers: Vec<TriggerEffect>,
}
```

An item is not much different, only that it also has an additional effect if used actively. Some items might have no held effect, some might not have an active effect, some might have both. Our system will allow for any combination.
```rs
pub struct ItemData {
    name: String,
    held: Vec<TriggerEffect>,
    active: Effect,
}
```

### More examples

I will give you some examples of how expressive we can make this DSL, I will add some enum values for illustration without specifying their exact implementation.

The move swords dance which is raising the users attack by 2 stages.
```rs
Move(
    name: "Swords Dance",
    types: [Normal],
    condition: Always,
    attempt: Attempt(
        condition: Always,
        success: StatChange(User, Attack, Exact(2)),
        failure: None,
        after: None,
    ),
)
```

The move toxic which will badly poison the opponent, if it has no status effect already.
```rs
Move(
    name: "Toxic",
    types: [Poison],
    condition: Always,
    attempt: Attempt(
        condition: Predicate(Prob(0.9)),
        success: Condition(
            cond: Not(Predicate(Target(Opponent, Predicate(HasAnyStatusEffect)))),
            success: ApplyStatus(Opponent, BadlyPoisoned),
            failure: None,
        ),
        failure: Miss,
        after: None,
    ),
)
```

The move triple axel which gets stronger with each attempt but will ultimately stop if it misses once.
```rs
Move(
    name: "Triple Axel",
    types: [Ice],
    condition: Always,
    attempt: Cascade(attempts: [
        Attempt(
            condition: Predicate(Prob(0.9)),
            success: TypeDamage(target: Opponent, category: Physical, power: Exact(20)),
            failure: Miss,
            after: None,
        ),
        Attempt(
            condition: Predicate(Prob(0.9)),
            success: TypeDamage(target: Opponent, category: Physical, power: Exact(40)),
            failure: Miss,
            after: None,
        ),
        Attempt(
            condition: Predicate(Prob(0.9)),
            success: TypeDamage(target: Opponent, category: Physical, power: Exact(60)),
            failure: Miss,
            after: None,
        ),
    ]),
)
```

The move solar beam which can hit instantly if the sun is out, else it has to charge for a turn. (Multi-turn moves might need some special care though).
```rs
Move(
    name: "Solar Beam",
    types: [Grass],
    condition: Always,
    attempt: Attempt(
        condition: Always,
        success: Condition(
            cond: Predicate(Target(User, Predicate(HasVolatile(Charging("Solar Beam"))))),
            success: Sequence(effects: [
                RemoveVolatile(User, Charging("Solar Beam")),
                TypeDamage(target: Opponent, category: Special, power: Exact(120)),
            ]),
            failure: Condition(
                cond: Predicate(HasFieldEffect(Sun)),
                success: TypeDamage(target: Opponent, category: Special, power: Exact(120)),
                failure: Sequence(effects: [
                    ApplyVolatile(User, Charging("Solar Beam")),
                    Message("is absorbing light!"),
                ]),
            ),
        ),
        failure: None,
        after: None,
    ),
)
```

The ability drizzle which will make it rain when the user is switched in.
```rs
Ability(
    name: "Drizzle",
    triggers: [
        TriggerEffect(
            trigger: SwitchIn(User),
            effect: SetFieldEffect(Rain, Exact(5)),
        ),
    ],
)
```

The ability speed boost which will raise the speed of the user at the end of each turn.
```rs
Ability(
    name: "Speed Boost",
    triggers: [
        TriggerEffect(
            trigger: TurnEnd,
            effect: StatChange(User, Speed, Exact(1)),
        ),
    ],
)
```

The ability poison heal which is healing the user if they would have taken poison damage this turn. We might be able to express this in a different way though, I dont know how well that SupressDefault work in the long run. I expect it to stop whatever would have come after that BeforePoisonDamage trigger but it might get messy.
```rs
Ability(
    name: "Poison Heal",
    triggers: [
        TriggerEffect(
            trigger: BeforePoisonDamage(User),
            effect: Condition(
                cond: Predicate(Target(User, Predicate(HasStatusEffect(Poison)))),
                success: Sequence(effects: [
                    SuppressDefault,
                    Heal(target: User, percent_of_max_hp: Exact(12)),
                ]),
                failure: None,
            ),
        ),
    ],
)
```

The leftovers item, which will heal the user at the end of each turn.
```rs
ItemData(
    name: "Leftovers",
    held: [
        TriggerEffect(
            trigger: TurnEnd,
            effect: Heal(target: User, percent_of_max_hp: Exact(6)),
        ),
    ],
    active: None,
)
```

The item focus sash which will prevent a pokemon from being one-hit K.O.'d.
```rs
ItemData(
    name: "Focus Sash",
    held: [
        TriggerEffect(
            trigger: BeforeFaint(User),
            effect: Condition(
                cond: Predicate(Target(User, Predicate(WasMaxHpBeforeHit))),
                success: Sequence(effects: [
                    SuppressDefault,
                    SetHp(target: User, Exact(1)),
                    ConsumeItem(User),
                    Message("held on using its Focus Sash!"),
                ]),
                failure: None,
            ),
        ),
    ],
    active: None,
)
```

And last but not least, the oran berry which can heal the user if below 50% HP when held OR when used directly as an item.
```rs
ItemData(
    name: "Oran Berry",
    held: [
        TriggerEffect(
            trigger: DamageDealt(User),
            effect: Condition(
                cond: Predicate(Target(User, Predicate(HpBelow(Percent(50))))),
                success: Sequence(effects: [
                    Heal(target: User, flat: Exact(10)),
                    ConsumeItem(User),
                ]),
                failure: None,
            ),
        ),
    ],
    active: Sequence(effects: [
        Heal(target: User, flat: Exact(10)),
        ConsumeItem(User),
    ]),
)
```

---

## Conclusion

While I dont think this is the **ULTIMATE** way of modeling Pokémon battles, I think it can be really fun and rewarding. I will definitely try to continue this project in the future and will report back if I made any significant breakthroughs, lol. As of right now its still a rough sketch and nothing truly functional has come of it yet.

I also think writing the DSL could become a bit tedious, so I definitely have to work on that too. There might be a way to parse the data from the Poké-API directly into my DSL, but thats for another day... >:)

---

## Repository

{{< github repo="Zitronenjoghurt/poke-dsl" showThumbnail=true >}}
