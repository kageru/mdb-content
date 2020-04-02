# Writing less code

Code is bad. It’s confusing, it’s easy to break, and it needs to be maintained or even updated.
And the more code you have, the worse it gets.

I sometimes get bored, perhaps more often than I’d like to admit,
  and one of the things I do to fight that boredom is writing code.
I’ve created lots of small pieces of software,
  most of which are awful, useless, or both.
My old blog may was one of them,
  although the exact classification into those categories
  shall be left as an exercise to the reader.

I realized the process of writing and uploading content to it was also anything but streamlined
  and likely contributed to my lack of motivation to write and release anything,
  so I decided to replace it.
At first, I thought about using [Jekyll](https://jekyllrb.com/),
  but remember, I’m bored and looking for opportunities to write code
  (which admittedly is the opposite of today’s title).

So I decided to rewrite it.
Not as another Python Django application, not as a Rails project or whatever people do these days.
No, I wanted to know how little I could get away with.
I wasn’t golfing for line count, obviously (because that’s just stupid),
  but I ideally wanted a simple shell script that would do everything I needed and only that.
I wanted to write markdown and get static HTML. Simple as that.
So here’s how you do that while writing as little code as possible:
```sh
$ pandoc input.md -t html > output.html
```
And that’s the secret to all of this.

## DRY? More like DRSE
The DRY principle (“don’t repeat yourself”) is something most programmers are familiar with
  and are probably trying to adhere to.
  Writing duplicate code feels inherently wrong to most people.
But why not take that one step further?
Don’t just not repeat yourself; don’t repeat someone else either.
If someone has already written software that converts markdown to html,
  you don’t have to do it again.
That part might have been obvious, but we can apply it to almost everything that is necessary for this little project
  (within reason, otherwise we wouldn’t write any code at all).

## The components
So what does my blog need to do?
Well, quite simple:

- read markdown and convert it to HTML
- generate an index of all the blog entries
- include some basic CSS/JS in the output
- update itself automatically when I publish something
- be compatible with the content from my previous blog

That last point might be the worst, but it’s what I wanted/needed.

The old blog had a simple sqlite database that would hold the title, date, and link of all blog posts.
It then had a predefined template for site header and footer and would just insert the content between those.
Relatively simple, but way more than what was necessary
  and also relatively slow because the template would be rendered for each request.
Oh, and I had to write the content directly in HTML.

Static pages converted from markdown would do the job just as well, so that was my new goal.

### Markdown conversion
The first and most obvious step is converting my hand-written markdown files to beatiful HTML for the browser.
As mentioned previously, I am going to use markdown for the conversion logic.

All I had to do now was define a folder structure which in my case has a `src` folder with all the .md files
  and a `content` folder with the resulting .html documents.
The rest is a simple loop and some shell built-ins.
```sh
convert_file() {
    path="$9"
    outpath="content/$(basename "$path" .md).html"
    pandoc "$path" -t html > "$outpath"
}

ls -ltu src/*.md | tail -n+1 | while read f; do convert_file $f; done
```

I used `ls -l` to have each file on a separate line which makes the parsing much easier.
`ls -tu` will sort the files by modification time so the newest entries are at the top.
`tail -n+1` removes the first line which is `total xxx` because of `-l`.

Step 1 done.

### Index generation

This problem was partially solved in the last step because A already had a list of all output paths sorted by edit date.
All that is left now is to generate some static html from that. I thus make some changes:
```sh
output() {
    echo "$1" >> index.html
}

create_entry() {
    # the code from step 1
    path="$9"
    outpath="content/$(basename "$path" .md).html"
    pandoc "$path" -t html > "$outpath"
    # and some html output
    output "<a href=\"$outpath\">$outpath</a>"
}

rm -f index.html # -f so it doesn’t fail if index.html doesn’t exist yet
ls -ltu src/*.md | tail -n+1 | while read f; do create_entry $f; done
```
That will give us a list of links to the blog entries with the filenames as titles,
but we can do better than that.
First, by extracting titles from the files.
This is based on the assumption that I begin every blog post with an h1 heading, or a single `# Heading` in markdown.
```sh
title="$(rg 'h1' "$outpath" | head -n1 | rg -o '(?<=>).*(?=<)' --pcre2)"
```
Match the first line that contains an h1 and return whatever is inside `>` and `<` – the title.

By then making the `src` directory part of a git repository
  (which I wanted to do anyway because it’s a good way to track changes),
  we can get the creation time of each file.
```sh
created=$(git log --follow --format=%as "$path" | tail -1)
```
`--format=%as` returns the creation date of a file as YYYY-MM-DD.
`man git-log` is your friend here.

We can combine this with some more static HTML to turn our index into a table with all the titles, dates, and links:
```sh
html_entry() {
    output '<tr>'
    path="$1"
    time="$2"
    title="$3"
    output "<td class=\"first\"><a href=\"$path\">$title</a></td>"
    output "<td class=\"second\">$time</td></tr>"
}

create_entry {
    # mentally insert previous code here
    # ...
    html_entry "$outpath" "created on $created" "$title"
}

rm -f index.html
output '<h1>Blog index</h1>'
output '<table>'
ls -ltu src/*.md | tail -n+1 | while read f; do create_entry $f; done
output '</table>'
```

It looks quite plain, but we have a fully functional index for our blog.
Onto step 3.

### Styling
For this, we can use a lesser known nginx feature that allows us to prepend something to the body of each page and append something after.
I changed the config and created a simple header as a static html file that would include the necessary resources.
```plaintext
location / {
    add_before_body /before_body.html;
    add_after_body /after_body.html;
    index index.html;
}
```

That’s it.
Next step.

### Automatic updates
At first, I had the entire script run every few minutes via `cron`,
  but markup conversion isn’t that cheap,
  so I only wanted to regenerate the files if something actually changed.

Since we’re already using git for the sources, we have everything we need.
I can simply check if there are changes upstream.

```sh
has_updates() {
    git fetch &> /dev/null
    diff="$(git diff master origin/master)"
    if [ "$diff" ]; then
        return 0
    else
        return 1
    fi
}

if has_updates; then
    # this merges origin/master into local master
    git pull
    # run the previous code
    ...
fi
```

I’m not super familiar with shell scripting,
  so if there’s a better way to do that boolean return in POSIX sh,
  feel free to [tell me](https://kageru.moe/contact/).

And now, the dreaded last step.

### Legacy garbage
That last part was actually quite simple.
I added a `legacy/index.html` with a hand-written list of all previous blog entries,
  and then made it appear last on the generated index with `entry "legacy" "before 2020" "Older posts"`.
Since I use nginx to add the header and footer to every page,
  the legacy index and legacy pages work almost out of the box.
After some slight adjustments to the old content pages, everything looks as intended.

## Summary
I now have a working static page generator for my blog in under 50 lines of shell code.
It does what I need and only that.
The code is (relatively) simple and fully POSIX sh compliant.
It’s not built to be super general or reusable, but that wasn’t the goal here.

I am aware that I built this with relatively little regard to dependencies.
Pandoc is huge, and the ripgrep call could be replaced with standard grep.
I know that, but for now, I don’t care.

If you want to take a look at the final result, the code is [on my gitea](https://git.kageru.moe/kageru/mdb).

I guess the only question now is: will this new blog give me the motivation to write more?
Only time will tell.  
I do have a few more ideas, and none of them are encoding-related. Sorry.



**Edit:** It was brought to my attention that this is very similar to [Luke Smith’s lb](https://github.com/LukeSmithxyz/lb).
I think the comparison is fair, but we seem to have different priorities.
He writes HTML; I write markdown.
He uses rsync; I want everything in git and also use that to sync.
He didn’t want dependencies; I… use pandoc. :^)

Still very interesting to see his approach to this, so thanks for pointing that out.

Now I’m considering adding RSS at some point. We’ll see.
