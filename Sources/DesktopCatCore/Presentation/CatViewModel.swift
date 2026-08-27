import Combine
import Foundation

@MainActor
public final class CatViewModel: ObservableObject {
    @Published public private(set) var activity: CatActivity = .sitting
    @Published public private(set) var expression: CatExpression = .neutral
    @Published public private(set) var reactionNonce: UInt64 = 0
    @Published public private(set) var state: PetState
    @Published public private(set) var selectedToy: CatToy?
    public private(set) var recentIdleActivities: [CatActivity] = []

    private let store: PetStateStore
    private let scheduler: CatScheduler
    private var contextualClickCount = 0

    public init(
        store: PetStateStore,
        scheduler: CatScheduler = CatScheduler(
            randomIndex: { upperBound in Int.random(in: 0..<max(1, upperBound)) }
        ),
        initialState: PetState? = nil
    ) {
        self.store = store
        self.scheduler = scheduler
        state = initialState ?? store.load()
        selectedToy = nil
    }

    @discardableResult
    public func handle(_ interaction: CatInteraction) -> CatReaction {
        let reaction: CatReaction
        switch interaction {
        case .click:
            switch contextualClickCount {
            case 0:
                reaction = CatReactionResolver.resolve(interaction, mood: state.mood)
            case 1:
                reaction = CatReaction(activity: .sitting, expression: .meow)
            default:
                reaction = CatReaction(activity: .lookingAround, expression: .startled)
            }
            contextualClickCount = (contextualClickCount + 1) % 3
        default:
            reaction = CatReactionResolver.resolve(interaction, mood: state.mood)
        }
        activity = reaction.activity
        expression = reaction.expression
        reactionNonce += 1
        return reaction
    }

    public func selectToy(_ toy: CatToy?) {
        selectedToy = toy
    }

    @discardableResult
    public func completeSelectedToy() -> CatReaction? {
        guard let selectedToy else { return nil }
        self.selectedToy = nil
        return handle(selectedToy.interaction)
    }

    public func updateState(_ update: (inout PetState) -> Void) {
        var changedState = state
        update(&changedState)
        state = changedState
        store.save(changedState)
    }

    public func scheduleIdleActivity(now: Date) {
        activity = scheduler.nextIdleActivity(
            now: now,
            personality: state.personality,
            mood: state.mood,
            recentActivities: recentIdleActivities
        )
        expression = .neutral
        recentIdleActivities.append(activity)
        recentIdleActivities = Array(recentIdleActivities.suffix(2))
    }
}
