module mutex {
  const CLIENTS: Set[str]
  const CHECK_FREE: bool

  type Owner = Free | Held(str)
  type Pc = Idle | Waiting | Critical

  var owner: Owner
  var pc: str -> Pc

  pure def isFree(o: Owner): bool = match o {
    | Free => true
    | Held(_) => false
  }

  action init = all {
    owner' = Free,
    pc' = CLIENTS.mapBy(_ => Idle),
  }

  action request(c: str): bool = all {
    pc.get(c) == Idle,
    pc' = pc.set(c, Waiting),
    owner' = owner,
  }

  action acquire(c: str): bool = all {
    pc.get(c) == Waiting,
    not(CHECK_FREE) or isFree(owner),
    owner' = Held(c),
    pc' = pc.set(c, Critical),
  }

  action release(c: str): bool = all {
    pc.get(c) == Critical,
    owner' = Free,
    pc' = pc.set(c, Idle),
  }

  action step = {
    nondet c = CLIENTS.oneOf()
    any { request(c), acquire(c), release(c) }
  }

  val inCritical = CLIENTS.filter(c => pc.get(c) == Critical)

  invariant freeMeansNobodyCritical = isFree(owner) implies inCritical == Set()
}

module mutexOk {
  import mutex(CLIENTS = Set("a", "b"), CHECK_FREE = true).*
  invariant atMostOneCritical = inCritical.size() <= 1
  observation twoWaiting = CLIENTS.filter(c => pc.get(c) == Waiting).size() >= 2
}

module mutexUnreached {
  import mutex(CLIENTS = Set("a", "b"), CHECK_FREE = true).*
  observation threeCritical = inCritical.size() >= 3
}

module mutexBuggy {
  import mutex(CLIENTS = Set("a", "b", "c"), CHECK_FREE = false).*
  invariant atMostOneCritical = inCritical.size() <= 1
  invariant ownerIsClient = match owner {
    | Free => true
    | Held(c) => CLIENTS.contains(c)
  }
  observation twoWaiting = CLIENTS.filter(c => pc.get(c) == Waiting).size() >= 2
}
