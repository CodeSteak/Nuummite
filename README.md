<img src="https://raw.githubusercontent.com/codesteak/nuummite/master/docs/nuummite.png" width="25%" align="right">

# Nuummite [![Build Status](https://travis-ci.org/CodeSteak/Nuummite.svg?branch=master)](https://travis-ci.org/CodeSteak/Nuummite)

Nuummite is a very small embedded key-value store. All data is kept
in RAM (in a Crystal Hash) and is also written to disk.
So don't use Nuummite to handle big chunks of data.
Keys and Values are always Strings.
It just comes with the most basic operations.

NOTE: Nuummite is still WIP.

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  nuummite:
    github: codesteak/nuummite
```


## Usage

```crystal
require "nuummite"
```

#### Open the database
```crystal
db = Nuummite.new("path/to/folder", "optional-filename.db")
```

#### Put some values in
```crystal
db["hello"] = "world"
db["42"] = "Answer to the Ultimate Question of Life, The Universe, and Everything"
db["whitespace"] = "Hey\n\t\t :D"
```

#### Read values
```crystal
db["hello"]? # => "world"
db["ehhhh"]? # => nil

#Note: db is locked while reading, so don't write to db!
db.each do |key,value|
  # reads everything
end

db["crystals/ruby"] = "9.0"
db["crystals/quartz"] = "~ 7.0"
db["crystals/nuummite"] = "5.5 - 6.0"

db.each("crystals/") do |key,value|
  # only crystals in here
end
```

#### Delete
```crystal
db.delete "hello"
```

#### Garbage collect
Since values are saved to disk in a log style, file sizes grow,
your key-value store needs to rewrite all data at some point:
```crystal
db.garbage_collect
```
By default it auto garbage collects after 10_000_000 writes.
To modify this behavior you can:
```crystal
# garbage collects after 1000 writes or deletes
db.auto_garbage_collect_after_writes = 1000

# does not auto garbage collect
db.auto_garbage_collect_after_writes = nil  
```

#### Shutdown
You can also shutdown Nuummite by
```crystal
db.shutdown
```

That's all you need to know :smile:

## Contributing

1. Fork it ( https://github.com/codesteak/nuummite/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [CodeSteak](https://github.com/CodeSteak) - creator, maintainer
