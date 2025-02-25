// RUN: %target-typecheck-verify-swift -disable-availability-checking -enable-experimental-feature VariadicGenerics

// REQUIRES: asserts

func tuplify<each T>(_ t: repeat each T) -> (repeat each T) {
  return (repeat each t)
}

func prepend<First, each Rest>(value: First, to rest: repeat each Rest) -> (First, repeat each Rest) {
  return (value, repeat each rest)
}

func concatenate<each T, each U>(_ first: repeat each T, with second: repeat each U) -> (repeat each T, repeat each U) {
  return (repeat each first, repeat each second)
}

func zip<each T, each U>(_ first: repeat each T, with second: repeat each U) -> (repeat (each T, each U)) {
  return (repeat (each first, each second))
}

func forward<each U>(_ u: repeat each U) -> (repeat each U) {
  return tuplify(repeat each u)
}

func forwardAndMap<each U, each V>(us u: repeat each U, vs v: repeat each V) -> (repeat [(each U, each V)]) {
  return tuplify(repeat [(each u, each v)])
}

func variadicMap<each T, each Result>(_ t: repeat each T, transform: repeat (each T) -> each Result) -> (repeat each Result) {
  return (repeat (each transform)(each t))
}

func coerceExpansion<each T>(_ value: repeat each T) {
  func promoteToOptional<each Wrapped>(_: repeat (each Wrapped)?) {}

  promoteToOptional(repeat each value)
}

func localValuePack<each T>(_ t: repeat each T) -> (repeat each T, repeat each T) {
  let local = repeat each t
  let localAnnotated: repeat each T = repeat each t
  // expected-error@-1{{value pack expansion can only appear inside a function argument list or tuple element}}

  return (repeat each local, repeat each localAnnotated)
}

protocol P {
  associatedtype A

  var value: A { get }

  func f(_ self: Self) -> Self
}

func outerArchetype<each T, U>(t: repeat each T, u: U) where repeat each T: P {
  let _: (repeat (each T.A, U)) = (repeat ((each t).value, u))
}

func sameElement<each T, U>(t: repeat each T, u: U) where repeat each T: P, repeat each T == U {
// expected-error@-1{{same-element requirements are not yet supported}}

  // FIXME: Opened element archetypes in diagnostics
  let _: (repeat each T) = (repeat (each t).f(u))
  // expected-error@-1 {{cannot convert value of type 'U' to expected argument type 'τ_1_0'}}
}

func forEachEach<each C, U>(c: repeat each C, function: (U) -> Void)
    where repeat each C: Collection, repeat (each C).Element == U {
    // expected-error@-1{{same-element requirements are not yet supported}}

  // FIXME: Opened element archetypes in diagnostics
  _ = (repeat (each c).forEach(function))
  // expected-error@-1 {{cannot convert value of type '(U) -> Void' to expected argument type '(τ_1_0.Element) throws -> Void'}}
}

func typeReprPacks<each T: ExpressibleByIntegerLiteral>(_ t: repeat each T) {
  _ = (repeat Array<each T>())
  _ = (repeat 1 as each T)

  _ = Array<each T>() // expected-error {{pack reference 'T' requires expansion using keyword 'repeat'}}
  _ = 1 as each T // expected-error {{pack reference 'T' requires expansion using keyword 'repeat'}}
  repeat Invalid<String, each T>("") // expected-error {{cannot find 'Invalid' in scope}}
}

func sameShapeDiagnostics<each T, each U>(t: repeat each T, u: repeat each U) {
  _ = (repeat (each t, each u)) // expected-error {{pack expansion requires that 'each U' and 'each T' have the same shape}}
  _ = (repeat Array<(each T, each U)>()) // expected-error {{pack expansion requires that 'each U' and 'each T' have the same shape}}
  _ = (repeat (Array<each T>(), each u)) // expected-error {{pack expansion requires that 'each U' and 'each T' have the same shape}}
}

func returnPackExpansionType<each T>(_ t: repeat each T) -> repeat each T { // expected-error {{pack expansion 'repeat each T' can only appear in a function parameter list, tuple element, or generic argument list}}
  fatalError()
}

func returnEachPackReference<each T>(_ t: repeat each T) -> each T { // expected-error {{pack reference 'T' requires expansion using keyword 'repeat'}}
  fatalError()
}

// expected-error@+1 {{pack type 'T' must be referenced with 'each'}}{{63-63=each }}
func returnRepeatTuple<each T>(_ t: repeat each T) -> (repeat T) {
  fatalError()
}

// expected-error@+2 {{pack reference 'T' requires expansion using keyword 'repeat'}}
// expected-error@+1 {{pack type 'T' must be referenced with 'each'}}{{55-55=each }}
func parameterAsPackTypeWithoutExpansion<each T>(_ t: T) {
}

// expected-error@+2 {{pack reference 'T' requires expansion using keyword 'repeat'}}
// expected-error@+1 {{pack type 'T' must be referenced with 'each'}}{{57-57=each }}
func returnPackReference<each T>(_ t: repeat each T) -> T {
  fatalError()
}

func packTypeParameterOutsidePackExpansionType<each T>(_ t: T,
  // expected-error@-1 {{pack reference 'T' requires expansion using keyword 'repeat'}}
  // expected-error@-2 {{pack type 'T' must be referenced with 'each'}}{{61-61=each }}
                                                       _ a: Array<T>) {
  // expected-error@-1 {{pack reference 'T' requires expansion using keyword 'repeat'}}
  // expected-error@-2 {{pack type 'T' must be referenced with 'each'}}{{67-67=each }}
}

func expansionOfNonPackType<T>(_ t: repeat each T) {}
// expected-error@-1 {{'each' cannot be applied to non-pack type 'T'}}{{29-29=each }}
// expected-error@-2 {{pack expansion 'T' must contain at least one pack reference}}

func tupleExpansion<each T, each U>(
  _ tuple1: (repeat each T),
  _ tuple2: (repeat each U)
) {
  _ = forward(repeat each tuple1.element)

  _ = zip(repeat each tuple1.element, with: repeat each tuple1.element)

  _ = zip(repeat each tuple1.element, with: repeat each tuple2.element)
  // expected-error@-1 {{global function 'zip(_:with:)' requires the type packs 'each U' and 'each T' have the same shape}}
}

protocol Generatable {
  static func generate() -> Self
}

func generateTuple<each T : Generatable>() -> (repeat each T) {
  (each T).generate()
  // expected-error@-1 {{pack reference 'T' requires expansion using keyword 'repeat'}}

  return (repeat (each T).generate())
}

func packElementInvalidBinding<each T>(_ arg: repeat each T) {
  _ = (repeat print(each arg))

  let x = 1
  repeat print(each x)
  // expected-error@-1 {{'each' cannot be applied to non-pack type 'Int'}}
  // TODO: fixit to remove 'each' keyword
}

func copyIntoTuple<each T>(_ arg: repeat each T) -> (repeat each T) {
  return (repeat each arg)
}
func callCopyAndBind<T>(_ arg: repeat each T) {
  // expected-error@-1 {{'each' cannot be applied to non-pack type 'T'}}{{22-22=each }}
  // expected-error@-2 {{pack expansion 'T' must contain at least one pack reference}}

  // Don't propagate errors for invalid declaration reference
  let result = copyIntoTuple(repeat each arg)
}

do {
  struct TestArgMatching {
    subscript<each T>(data arg: repeat each T) -> Int {
      get { 42 }
      set {}
    }

    subscript<each T>(simpleTuple args: (repeat each T)) -> Int {
      get { return 0 }
      set {}
    }

    subscript<each T>(compoundTuple args: (String, repeat each T)) -> Int {
      get { return 0 }
      set {}
    }
  }

  func test_that_variadic_generics_claim_unlabeled_arguments<each T>(_ args: repeat each T, test: inout TestArgMatching, extra: String) {
    func testLabeled<each U>(data: repeat each U) {}
    func testUnlabeled<each U>(_: repeat each U) {}
    func testInBetween<each U>(_: repeat each U, other: String) {}

    testLabeled(data: repeat each args) // Ok
    testLabeled(data: repeat each args, 1) // Ok
    testLabeled(data: repeat each args, 1, 2, 3) // Ok

    testUnlabeled(repeat each args) // Ok
    testUnlabeled(repeat each args, 1) // Ok
    testUnlabeled(repeat each args, 1, 2, 3) // Ok

    testInBetween(repeat each args, 1, 2.0, other: "") // Ok

    _ = test[data: repeat each args]
    _ = test[data: repeat each args, 0, ""]

    test[data: repeat each args, "", 42] = 0

    do {
      let first = ""
      let second = ""
      let third = 42

      _ = test[simpleTuple: (repeat each args)]
      _ = test[simpleTuple: (repeat each args, extra)]
      _ = test[simpleTuple: (first, second)]
      _ = test[compoundTuple: (first, repeat each args)]
      _ = test[compoundTuple: (first, repeat each args, extra)]
      _ = test[compoundTuple: (first, second, third)]
    }

    do {
      func testRef<each T>() -> (repeat each T, String) { fatalError() }
      func testResult<each T>() -> (repeat each T) { fatalError() }

      func experiment1<each U>() -> (repeat each U, String) {
        testResult() // Ok
      }

      func experiment2<each U>(_: () -> (repeat each U)) -> (repeat each U) { fatalError() }
      let _: (Int, String) = experiment2(testRef) // Ok
    }
  }
}

func test_pack_expansion_materialization_from_lvalue_base() {
  struct Data<Value> {}

  struct Test<each T> {
    var data: (repeat Data<each T>)

    init() {
      self.data = (repeat Data<each T>())
      _ = (repeat each data.element) // Ok

      var tmp = (repeat Data<each T>()) // expected-warning {{never mutated}}
      _ = (repeat each tmp.element) // Ok

      // TODO: Add subscript test-case when syntax is supported.
    }
  }
}

func takesFunctionPack<each T, R>(functions: repeat ((each T) -> R)) {}

func forwardFunctionPack<each T>(functions: repeat (each T) -> Bool) {
  takesFunctionPack(functions: repeat each functions)
}

func packOutsideExpansion<each T>(_ t: repeat each T) {
  _ = t
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}

  forward(t)
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}

  _ = each t
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}

  forward(each t)
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}

  let tuple = (repeat each t)

  _ = tuple.element
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}

  _ = each tuple.element
  // expected-error@-1{{pack reference 'each T' can only appear in pack expansion}}
}

func identity<T>(_ t: T) -> T { t }
func concrete(_: Int) {}

func invalidRepeat<each T>(t: repeat each T) {
  _ = repeat each t
  // expected-error@-1 {{value pack expansion can only appear inside a function argument list or tuple element}}

  let _: Int = repeat each t
  // expected-error@-1 {{value pack expansion can only appear inside a function argument list or tuple element}}

  identity(identity(repeat each t))
  // expected-error@-1 {{cannot pass value pack expansion to non-pack parameter of type 'T'}}

  concrete(repeat each t)
  // expected-error@-1 {{cannot pass value pack expansion to non-pack parameter of type 'Int'}}

  _ = [repeat each t]
  // expected-error@-1 {{value pack expansion can only appear inside a function argument list or tuple element}}
}

// Make sure that single parameter initializers are handled correctly because
// the have special type-checking rules in Swift < 6.
func test_init_refs_with_single_pack_expansion_param() {
  struct Data<each V> {
    init(_: repeat each V) {}
  }

  _ = Data() // Ok
  _ = Data(42) // Ok
  _ = Data(42, "") // Ok

  struct EmptyAmbiguous<each V> {
    init(_: repeat each V) {} // expected-note {{found this candidate}}
    init(x: repeat each V) {} // expected-note {{found this candidate}}
  }

  _ = EmptyAmbiguous() // expected-error {{ambiguous use of 'init'}}
  _ = EmptyAmbiguous(x: 42)
  _ = EmptyAmbiguous(x: (42, "")) // Ok
}

func test_pack_expansions_with_closures() {
  func takesVariadicFunction<each T>(function: (repeat each T) -> Int) {}

  func test(fn: (Int, String) -> Int, x: Int) {
    takesVariadicFunction { fn(x, "") } // Ok
    takesVariadicFunction { y in fn(x, y) } // Ok
    takesVariadicFunction { y, z in fn(y, z) } // Ok
  }
}

// rdar://107151854 - crash on invalid due to specialized pack expansion
func test_pack_expansion_specialization() {
  struct Data<each T> {
    init(_: repeat each T) {} // expected-note 2 {{'init(_:)' declared here}}
    init(vals: repeat each T) {} // expected-note 2 {{'init(vals:)' declared here}}
  }

  _ = Data<Int>() // expected-error {{missing argument for parameter #1 in call}}
  _ = Data<Int>(0) // Ok
  _ = Data<Int, String>(42, "") // Ok
  _ = Data<Int>(42, "") // expected-error {{extra argument in call}}
  _ = Data<Int, String>((42, ""))
  // expected-error@-1 {{initializer expects 2 separate arguments; remove extra parentheses to change tuple into separate arguments}}
  _ = Data<Int, String, Float>(vals: (42, "", 0))
  // expected-error@-1 {{initializer expects 3 separate arguments; remove extra parentheses to change tuple into separate arguments}}
  _ = Data<Int, String, Float>((vals: 42, "", 0))
  // expected-error@-1 {{initializer expects 3 separate arguments; remove extra parentheses to change tuple into separate arguments}}
}

// rdar://107280056 - "Ambiguous without more context" with opaque return type + variadics
protocol Q {
  associatedtype B
}

do {
  struct G<each T>: Q {
    typealias B = (repeat each T)
  }

  func f<each T>(_: repeat each T) -> some Q {
    return G<repeat each T>() // Ok
  }
}

// Make sure that in-exact matches (that require any sort of conversion or load) on arguments are handled correctly.
do {
  var v: Float = 42 // expected-warning {{variable 'v' was never mutated; consider changing to 'let' constant}}

  func testOpt<each T>(x: Int?, _: repeat each T) {}
  testOpt(x: 42, "", v) // Load + Optional promotion

  func testLoad<each T, each U>(t: repeat each T, u: repeat each U) {}
  testLoad(t: "", v) // Load + default
  testLoad(t: "", v, u: v, 0.0) // Two loads

  func testDefaultWithExtra<each T, each U>(t: repeat each T, u: repeat each U, extra: Int?) {}
  testDefaultWithExtra(t: "", v, extra: 42)

  func defaults1<each T>(x: Int? = nil, _: repeat each T) {}
  defaults1("", 3.14) // Ok

  func defaults2<each T>(_: repeat each T, x: Int? = nil) {}
  defaults2("", 3.14) // Ok

  func defaults3<each T, each U>(t: repeat each T, u: repeat each U, extra: Int? = nil) {}
  defaults3(t: "", 3.14) // Ok
  defaults3(t: "", 3.14, u: 0, v) // Ok
  defaults3(t: "", 3.14, u: 0, v, extra: 42) // Ok

  struct Defaulted<each T> {
    init(t: repeat each T, extra: Int? = nil) {}
    init<each U>(t: repeat each T, u: repeat each U, other: Int? = nil) {}
  }

  _ = Defaulted(t: "a", 0, 1.0) // Ok
  _ = Defaulted(t: "b", 0) // Ok
  _ = Defaulted(t: "c", 1.0, u: "d", 0) // Ok
}
