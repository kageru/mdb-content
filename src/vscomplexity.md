# Complexity killed the cat

Note: this is quite specific to video encoding.
Please don’t read this and then scream “kageru doesn’t want people to write idiomatic code”.
Thank you.

---

Complexity is a known problem.
Lots of people have written about it at length,
  and almost everyone seems to agree that complexity is something to avoid when writing software.
Still, it seems to appear wherever we go.
What is it that makes it so tempting and so hard to control?

I recently realized that even video encoding (that is, filtering and encoding like many fansubbers do) is no longer safe.
The complexity distribution in encoding used to be very simple:  
A select few people write plugins in C/C++, some of which use pretty fancy math, to accomplish a specific task.
Everyone else then uses a simple scripting language to combine these plugins.
Back in the Avisynth days, that might have looked like this:

```sh
# read source
FFVideoSource("my_file.mp4")
# resize
Spline36Resize(1280, 720)
# deband
f3kdb(18, 64, 64)
```

The scripting language allowed for function definitions,
  conditionals via the [ternary operator](https://en.wikipedia.org/wiki/%3F:)
  (but no if/else keywords),
  and loops were implemented with recursion.
The language was pretty limited,
  and that proved to be quite painful when more complex logic was needed,
  but people somehow made it work,
  often creating unreadable operator chains and recursive rabbit holes.

## Introducing: a proper scripting language

For Vapoursynth, the modern replacement of Avisynth[^replacement],
  no custom language was implemented for the scripts.
Instead, Python was used.
That allowed users to replace the dreaded ternary nesting with much simpler if/elif/else chains
  and just gave them more freedom overall.

[^replacement]: I say replacement, but there are still lots of people who refuse to switch, even in $currentYear.

For a while, this resulted in much more readable and straight-forward scripts.
But, just like all newfound powers, it would soon be misused.

One early example was the port of TAA.
Not only does the only public function it defines accept 25 parameters (one of those a 2-element tuple) *and* `**kwargs` and has 17 explicit `raise` statements, it also defines no fewer than 12 classes,
  which form an inheritance hierarchy with 5 levels.
It also contains this gem:

```py
# Use lambda for lazy evaluation
mask_kernel = {
    0: lambda: lambda a, b, *args, **kwargs: b,
    1: lambda: mask_lthresh(clip, mthr, mlthresh, mask_sobel, mpand, opencl=opencl,
                            opencl_device=opencl_device, **kwargs),
    2: lambda: mask_lthresh(clip, mthr, mlthresh, mask_robert, mpand, **kwargs),
    # goes on like that for 10 more cases, some of which use string keys
}
```

It’s 700 lines of pure overengineered obfuscation
  because someone decided to bring enterprise Java into the encoding world.[^nobully]
It does what it’s supposed to do,
  but I don’t think new encoders will be able to learn much from it or change it to their needs – which is often more important
  because you, the maintainer, won’t always be around to make the necessary adjustments.

Don’t create the ancient and arcane scriptures of tomorrow.
There are too many of those already.

[^nobully]: There are more examples like this one, TAA has just been bugging me for a long time.
It’s by no means the only script that has grown far beyond critical mass.

## Taking the fun out of functions

TAA showed years ago how do to idiomatic enterprise Java in Vapoursynth.
Being a Kotlin developer, I of course had other ideas of what good code should look like.[^ktfun]
Why should I let people pass 20 parameters and `**kwargs` down my inheritance hierarchy when they could just give me a few `Callables` instead?

[^ktfun]: Kotlin functions often take functional arguments, which is well-supported by the syntax and also much easier if you have statically checked types.
That obviously does not translate to Python,
  but it doesn’t stop me from trying.

Say you have an AA script that passes `kwargs` to an internal function,
  but you also want to accept parameters for a resizer call and give the user the choice between two common resizers.
Where before you would write:

```py
def some_aa_filter(clip: VideoNode, width: int, height: int, depth: int, kernel: str, chroma_pos: int, fmtc_chroma_pos: str, use_zimg = True, **kwargs) -> VideoNode:
    clip = aa(**kwargs)
    if use_zimg:
        return zimg_resizer(clip, width, height, kernel, chroma_pos)
    return core.fmtc.resample(clip, width, height, depth, kernel, fmtc_chroma_pos)
```

you could now do this:

```py
def some_aa_filter(clip: VideoNode, width: int, height: int, resizer: Callable[[VideoNode, int, int], VideoNode], **kwargs) -> VideoNode:
    clip = aa(**kwargs)
    return resizer(clip, width, height)
```

No need to have all those parameters for the resizer that someone may or may not wish to specify at some point.
I could even provide a default value for the `resizer` argument that just uses a bicubic resize,
  and if someone wanted to specify their own resizer, they could totally do that.
Sounds great until you realize that the caller now has to understand functional arguments and create them either with a `lambda` or something like `functools.partial`.
Both are nontrivial for the target audience,
  which mostly consists of regular people (i.e. not programmers)
  who just want to save their favorite anime from whatever the mastering company did to it this time.

But they can handle this, right?
It’s just a little bit of complexity that gives them *sooo* much more freedom.

The real use case was a little more complicated than just an AA function,
  and I decided to keep the callable.
I felt it was necessary to make the function useful,
  but I later realized it’s very easy to go too far with this.
Being the person who wrote the code,
  I often don’t realize what parts are difficult to understand.
I think most of us have experienced that at some point.

## How much is too much?

I was recently confronted with this when someone opened a [pull request for vsutil](https://github.com/Irrational-Encoding-Wizardry/vsutil/pull/37)
which added decorators for things like `@disallow_variable_format`.

In one of my comments, I wrote:

> “Having decorators at all is already a level of complexity that might scare away potential contributors (most VS users don’t know much about Python), but I think they’re quite self-explanatory in this case, so I’m fine with that.”

to which someone replied:

> “vsutil is already beyond this point with using typehints and unit tests in the first place imo.”

While I personally disagree that typehints and unit tests obfuscate code as much as decorators and other Python magic,
  it still got me thinking.
Not because I desperately want contributors with zero programming knowledge,
  but because I would like to create code that the target audience can actually read and understand.
People can’t learn from code that they can’t understand at all,
  and I believe that reading other people’s code is a good way to improve your own.

I certainly learned a lot (about encoding but also in general) by doing that.
Not everyone has the luxury of a personal mentor,
  but everyone can go on Github,
  read the code of more experienced encoders,
  and learn from that.[^copy]

[^copy]: but please don’t just copy code.
If you want to copy something because it does exactly what you need,
  at least try to understand it beforehand.
I still regret merging a kagefunc PR once without properly going through the code,
  because it left me with 50 lines that I barely understood myself
  and have been procrastinating to refactor ever since.

There are more factors than just the code itself.
Some repositories, vsutil included, have slowly turned into proper Python modules.
That’s not a bad thing per se because it gives us the ability to publish PyPi packages
  which also simplifies packaging for the AUR or similar repositories,
  but there is a point at which it makes the folder structure confusing.
I think this is stil within reason,[^init] but we should be careful to keep it that way.

[^init]: having all of the vsutil code in `__init__.py` does seem weird to me, but that has already been discussed and should change soon.

Complexity rarely comes all at once.
It’s death by a thousand pull requests that slowly make everything more and more complicated,
  one reasonable step at a time,
  and before you know it,
  you don’t understand your own repository.

Maybe I’m too afraid to reject pull requests because “someone put a lot of work into this”,
  but thinking more about this made me realize that just blindly accepting them will do a lot more harm over time.

## The complex is the enemy of the good

Maybe we should only stray from the basics when absolutely necessary,
  no matter what your (or my) favorite programming style is.
Video filtering is about scripting,
  not understanding someone’s OOP hierarchies,
  reimplementing popular FP patterns,
  or emulating any other programming paradigm.

If someone approaches you becauses they can’t figure out how to call a function you’ve written,
  it’s probably your fault and not theirs.[^dep]

[^dep]: Unless they’re just missing a dependency and can’t read the error message.




What I really want to say is:
  please just think twice before turning a 100 line file of helper functions
  into a 2000 loc project that is 50% docstrings,
  40% error handling, has 5 `@decorators` per function, 3 different linters,
  and reads like the Haskell code of a drunk freshman transpiled to Python.

I promise I’ll try to do the same, even if it means typing three lines instead of just one.[^reduce]

[^reduce]: And trust me, I’ll miss  
  `def iterate(base, function, count): return reduce(lambda v, _: function(v), range(count), base)`,  
  but a simple `for` loop is just much more readable to non-FP people.
