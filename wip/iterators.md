# Stream, Sequence, Iterator – a story of laziness and sad benchmarking noises
Many programming languages have started to include more functional features in their standard libraries.
    One of those features is lazy collections, for lack of a better term,
    which seem to have a different name in each language
    (we’ll just call them iterators here)
    and sometimes vastly differing implementations.
    One thing they all have in common, though, is a lack of trust in their performance.

For almost every language out there that offers lazy iterators,
    there will be people telling you not to use them for performance reasons,
    more often than not without any data to back that up.

I was personally interested in this because, being a Java/Kotlin developer,
    I use Java’s Streams and Kotlin’s Sequences almost every day
    with relatively little regard for performance.
    They are intuitive to write and are easy to reason about,
    which is usually much more important than the results of a thousand microbenchmarks,
    so please don’t stop using your favorite language feature because it’s 2.8% slower than the primitive alternative.

Still, I wanted to know how they compare to imperative code.
There are some resources on this for Java 8’s Stream API,
    but Kotlin’s Sequences seem to just be accepted as
    more convenient Streams[^convenience].
    Rust is here as a baseline for comparisons
    because it is generally regarded as having very optimized iterators.

[^convenience]: If you’ve ever used them, you’ll know what I mean.
    Java’s Streams are built in a way that allows for easy parallelism,
    but brings its own problems and limitations for the usage.
    We’ll see some of that in the code examples later.

## What *is* an iterator?
You can think of an iterator as a pipeline of data.
    It’s not a list, so it doesn’t support indexing,
    because it doesn’t actually hold any data.
    It just contains information on how to get or make that data.  
    You can make it produce data and use that
    (which is often called ‘consuming’ the iterator
    because if you read data from the pipeline, it’s usually gone),
    or you can add a new step to the pipeline and hand the result to someone else,
    who can then consume it or add even more operations.  
    You also don’t know when (or if at all) an iterator will end.
    Someone could sit at the other end and constantly put new data into your pipeline.

An important aspect to note is: adding an operation to the pipeline does nothing
    until someone actually starts reading from it,
    and even then, only the elements that are consumed are computed.[^inf]

[^inf]: This is what makes infinite iterators possible to begin with.

