module mutex_test {
  import mutex(CLIENTS = Set("a", "b"), CHECK_FREE = true).* from "./mutex"

  run handOverTest =
    init
      .then(request("a"))
      .then(request("b"))
      .then(acquire("a"))
      .then(release("a"))
      .then(acquire("b"))
      .expect(inCritical == Set("b"))

  run wrongOwnerTest =
    init
      .then(request("a"))
      .then(acquire("a"))
      .expect(owner == Free)
}
