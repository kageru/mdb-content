# Java isn’t bad; the world is
Few languages are seen as unfavourably by almost any programmer as Java.
Sure, people make jokes about COBOL and esoteric languages like Brainfuck or even Javascript,
but of the ones that are actively being used (outside of old bank software :^)),
few come close to the infamity of Java,
and unlike with many things, most people can actually explain why they feel that way.

And I get it.
I’m working full-time as a software deveoper on a 2 million line Java backend monolith that is slowly
    (and I mean *slowly*) being broken down into Kotlin microservices.
I have read, modified, and refactored code that was created before I wrote my first line of code in middle school,
    and yes, some of it is really bad.
The kind of bad that I rarely (not never) see in the Kotlin parts of our codebase.

But why is that?

I wrote a small microservice in modern Java
    to see what Java could feel and look like if you’re not bound by ancient versions or weird coding standards,
    and I’m quite satisfied with the results.
In this post,
    I’ll first go over the problems that Java codebases or projects often have
    and in the end share some impressions of the little service I wrote.

## Mindset and code

The problem with Java often isn’t what the language does or does not allow, but what people consciously decide to do.
I’ve definitely fallen into enterprise traps and written useless boilerplate, abstraction layers, or “extensible, reusable code”.

### Reusability

Writing overly reusable code is a mistake to learn from, and one important takeaway for me was this:

Try to make code easy to remove, not easy to reuse.  
If something can easily be deleted,
that usually means it’s either simple or the complexity is contained in a way that doesn’t add too much maintenance effort to the code that already exists.
It will also save yourself or your coworkers time and effort once the requirements change or the feature is simply no longer needed.
Too much code is written with a “this is great and could/should be reused elsewhere” mindset that leads to overly complicated and generic implementations for very specific problems.
Code is rarely ever reused elsewhere.
A good rule of thumb is to extract somethingn into a shared library or subproject once it’s needed in at least three different places.[^exceptcol]

[^exceptcol]: There are a few obvious exceptions to this. If you define your own container or collection types, those should obviously be generic right from the start.

Reusability is also one of the biggest reasons for another common issue: excessive abstractions.

### Abstractions
Java developers love putting everything behind interfaces.
Someone somewhere once said that you should only pass around interfaces,
    so that’s what people started doing.
Most of these interfaces will have a single real implementation and maybe another one for tests where that was easier than using a mock[^mocks].

[^mocks]: Which should rarely be the case.
    If you don’t want to mock everything in your tests,
    start making your classes so simple they can be instantiated manually in tests
    without needing dependency injection and other such magic.

Modern IDEs make it easy to find that implementation,
    and the name is often something like MyInterfaceImpl that would be easy to find,
    but you still had to write an entire file of copy-pasted method declarations that will just pollute the namespace.
And this doesn’t just happen for services or other logic-heavy parts of the code,
    but even for business beans that just hold data.
I’ve seen hierarchies like

```java
// defines 10 getters
interface Something
// defines 5 more getters
interface SomethingExtended
// defines 5 more getters
interface SomethingTexts
// implements about half of the logic
abstract class AbstractSomething implements Something, SomethingExtended, SomethingTexts {}
// implements the rest
class SomethingImpl extends AbstractSomething

/* And then for unit tests: */

// used in unit tests because constructing a real SomethingImpl is almost impossible
class SomethingForTest extends AbstractSomething
```

that make it more difficult to know what methods are defined on what type and where (IDEs help with this)
    or what types you’re actually dealing with
    (it’s not apparent at first that a Something/SomethingExtended/SomethingTexts is actually always just a SomethingImpl).
One could argue that the latter is an implementation default that is purposely hidden,
    but chances are you will need that information at some point, but just having it in plain sight doesn’t cause any harm.

The abstraction hell can be taken to the next level when you add generics:

```java
abstract class <T extends Product> MyAbstractEnterpriseProductProviderFactory<T> implements EnterpriseProviderFactory<Product, T>
```

or similar nonsense.
Those inheritance trees can be upwards of 10 levels high
    with an increasing number of generic parameters as you approach the root.
Sometimes there’s only a single actual implementation
    either because whoever built it assumed that more would be added later
    or because there used to be many,
    but all but one were no longer needed,
    and cleaning up the entire inheritance tree was too much work,
    so it was just left as-is.

With the addition of `default` methods in Java 8, the interface hell became a lot more useful
    because now, I programmer could think about the parts of the interface that should be the same in all implementations
    and only leave a few remaining parts to the specific implementations.
    That’s sounds better, but I haven’t seen it in practice as often as I’d like.

### `null`

The examples so far are all caused by programmers who made questionable decisions,
    but a text about Java wouldn’t be complete without a section about the billion dollar mistake of the null dereference.
This isn’t a Java problem specifically,
    but it does come up a lot more than in most other languages because Java very liberally uses `null` returns everywhere,
    and this was definitely a problem in earlier versions.
With Java 8, they introduced `java.util.Optional<T>`
    which should be returned instead of null values to signal that a method may or may not produce a usable output.
In an ideal world, all libraries would have stopped returning null and instead switch to optionals,
    replacing the common null check chains:

```java
// Find the orders of a user for display on the profile page.
// Falls back to an empty list if the user is unknown.
List<Order> findOrders(String email) {
    User user = userService.findByMail(email);
    if (user == null) {
        return Collections.emptyList();
    }
    List<Order> orders = orderService.findByUserId(user.getId());
    if (orders == null) {
        return Collections.emptyList();
    }
    return orders;
```

with

```java
List<Order> findOrders(String email) {
    return Optional.ofNullable(userService.findByMail(email))    // Optional<User>
        .map(User::getId)                                        // Optional<UserId>
        .flatMap(orderService::findByUserId)                     // Optional<List<Order>>
        .getOrElse(() -> Collections.emptyList());               // List<Order>
}
```

There’s less room for error, and you’re not distracted by all the bloat that nullchecks add.
The problem is, obviously, that we don’t live in an ideal world.
The Java standard library is encumbered by promises of backwards compatibility,
    so the `null` returns are there to stay,
    and most external libraries didn’t update either,
    either to remain compatible with older Java versions for a few years until the enterprise world had caught up,
    or because they simply didn’t want to switch to Optionals.
Which is fair because it’s quite a drastic change that will cost you and your users a lot of time,
    and this is the kind of time that stakeholders rarely want to pay for.

If you start a project from scratch now, this is a great way to solve the nullability problem.
Nullable calls to external libraries could be wrapped into Optionals right where they happen,
    and everything in your application would be nullsafe.
But many software developers just join existing projects,
    and even if you were to start a new project now,
    Java probably wouldn’t be the language many people would choose.
Not with Kotlin or even Scala around,
    or languages that are not crippled by the JVM at all,
    but that’s for a later section.


notes: exceptions for control flow; unsupportedoperationexception
