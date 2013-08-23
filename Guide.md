
## About FriendlyId

FriendlyId is an add-on to Ruby's Active Record that allows you to replace ids
in your URLs with strings:

    # without FriendlyId
    http://example.com/states/4323454

    # with FriendlyId
    http://example.com/states/washington

It requires few changes to your application code and offers flexibility,
performance and a well-documented codebase.

### Core Concepts

#### Slugs

The concept of *slugs* is at the heart of FriendlyId.

A slug is the part of a URL which identifies a page using human-readable
keywords, rather than an opaque identifier such as a numeric id. This can make
your application more friendly both for users and search engine.

#### Finders: Slugs Act Like Numeric IDs

To the extent possible, FriendlyId lets you treat text-based identifiers like
normal IDs. This means that you can perform finds with slugs just like you do
with numeric ids:

    Person.find(82542335)
    Person.friendly.find("joe")


## Setting Up FriendlyId in Your Model

To use FriendlyId in your ActiveRecord models, you must first either extend or
include the FriendlyId module (it makes no difference), then invoke the
{FriendlyId::Base#friendly_id friendly_id} method to configure your desired
options:

    class Foo < ActiveRecord::Base
      include FriendlyId
      friendly_id :bar, :use => [:slugged, :simple_i18n]
    end

The most important option is `:use`, which you use to tell FriendlyId which
addons it should use. See the documentation for this method for a list of all
available addons, or skim through the rest of the docs to get a high-level
overview.

### The Default Setup: Simple Models

The simplest way to use FriendlyId is with a model that has a uniquely indexed
column with no spaces or special characters, and that is seldom or never
updated. The most common example of this is a user name:

    class User < ActiveRecord::Base
      extend FriendlyId
      friendly_id :login
      validates_format_of :login, :with => /\A[a-z0-9]+\z/i
    end

    @user = User.friendly.find "joe"   # the old User.find(1) still works, too
    @user.to_param                     # returns "joe"
    redirect_to @user                  # the URL will be /users/joe

In this case, FriendlyId assumes you want to use the column as-is; it will never
modify the value of the column, and your application should ensure that the
value is unique and admissible in a URL:

    class City < ActiveRecord::Base
      extend FriendlyId
      friendly_id :name
    end

    @city.friendly.find "Viña del Mar"
    redirect_to @city # the URL will be /cities/Viña%20del%20Mar

Writing the code to process an arbitrary string into a good identifier for use
in a URL can be repetitive and surprisingly tricky, so for this reason it's
often better and easier to use {FriendlyId::Slugged slugs}.

## Performing Finds with FriendlyId

FriendlyId offers enhanced finders which will search for your record by
friendly id, and fall back to the numeric id if necessary. This makes it easy
to add FriendlyId to an existing application with minimal code modification.

By default, these methods are available only on the `friendly` scope:

    Restaurant.friendly.find('plaza-diner') #=> works
    Restaurant.friendly.find(23)            #=> also works
    Restaurant.find(23)                     #=> still works
    Restaurant.find('plaza-diner')          #=> will not work

### Restoring FriendlyId 4.0-style finders

Prior to version 5.0, FriendlyId overrode the default finder methods to perform
friendly finds all the time. This required modifying parts of Rails that did
not have a public API, which was harder to maintain and at times caused
compatiblity problems. In 5.0 we decided change the library's defaults and add
the friendly finder methods only to the `friendly` scope in order to boost
compatiblity. However, you can still opt-in to original functionality very
easily by using the `:finders` addon:

    class Restaurant < ActiveRecord::Base
      extend FriendlyId

      scope :active, -> {where(:active => true)}

      friendly_id :name, :use => [:slugged, :finders]
    end

    Restaurant.friendly.find('plaza-diner') #=> works
    Restaurant.find('plaza-diner')          #=> now also works
    Restaurant.active.find('plaza-diner')   #=> now also works

### Updating your application to use FriendlyId's finders

Unless you've chosen to use the `:finders` addon, be sure to modify the finders
in your controllers to use the `friendly` scope. For example:

    # before
    def set_restaurant
      @restaurant = Restaurant.find(params[:id])
    end

    # after
    def set_restaurant
      @restaurant = Restaurant.friendly.find(params[:id])
    end


## Slugged Models

FriendlyId can use a separate column to store slugs for models which require
some text processing.

For example, blog applications typically use a post title to provide the basis
of a search engine friendly URL. Such identifiers typically lack uppercase
characters, use ASCII to approximate UTF-8 character, and strip out other
characters which may make them aesthetically unappealing or error-prone when
used in a URL.

    class Post < ActiveRecord::Base
      extend FriendlyId
      friendly_id :title, :use => :slugged
    end

    @post = Post.create(:title => "This is the first post!")
    @post.friendly_id   # returns "this-is-the-first-post"
    redirect_to @post   # the URL will be /posts/this-is-the-first-post

In general, use slugs by default unless you know for sure you don't need them.
To activate the slugging functionality, use the {FriendlyId::Slugged} module.

FriendlyId will generate slugs from a method or column that you specify, and
store them in a field in your model. By default, this field must be named
`:slug`, though you may change this using the
{FriendlyId::Slugged::Configuration#slug_column slug_column} configuration
option. You should add an index to this column, and in most cases, make it
unique. You may also wish to constrain it to NOT NULL, but this depends on your
app's behavior and requirements.

### Example Setup

    # your model
    class Post < ActiveRecord::Base
      extend FriendlyId
      friendly_id :title, :use => :slugged
      validates_presence_of :title, :slug, :body
    end

    # a migration
    class CreatePosts < ActiveRecord::Migration
      def self.up
        create_table :posts do |t|
          t.string :title, :null => false
          t.string :slug, :null => false
          t.text :body
        end

        add_index :posts, :slug, :unique => true
      end

      def self.down
        drop_table :posts
      end
    end

### Working With Slugs

#### Formatting

By default, FriendlyId uses Active Support's
[paramaterize](http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-parameterize)
method to create slugs. This method will intelligently replace spaces with
dashes, and Unicode Latin characters with ASCII approximations:

    movie = Movie.create! :title => "Der Preis fürs Überleben"
    movie.slug #=> "der-preis-furs-uberleben"

#### Column or Method?

FriendlyId always uses a method as the basis of the slug text - not a column. It
first glance, this may sound confusing, but remember that Active Record provides
methods for each column in a model's associated table, and that's what
FriendlyId uses.

Here's an example of a class that uses a custom method to generate the slug:

    class Person < ActiveRecord::Base
      friendly_id :name_and_location
      def name_and_location
        "#{name} from #{location}"
      end
    end

    bob = Person.create! :name => "Bob Smith", :location => "New York City"
    bob.friendly_id #=> "bob-smith-from-new-york-city"

FriendlyId refers to this internally as the "base" method.

#### Uniqueness

When you try to insert a record that would generate a duplicate friendly id,
FriendlyId will append a UUID to the generated slug to ensure uniqueness:

    car = Car.create :title => "Peugot 206"
    car2 = Car.create :title => "Peugot 206"

    car.friendly_id #=> "peugot-206"
    car2.friendly_id #=> "peugot-206-f9f3789a-daec-4156-af1d-fab81aa16ee5"

Previous versions of FriendlyId appended a numeric sequence a to make slugs
unique, but this was removed to simplify using FriendlyId in concurrent code.

#### Candidates

Since UUIDs are ugly, FriendlyId provides a "slug candidates" functionality to
let you specify alternate slugs to use in the event the one you want to use is
already taken. For example:

    class Restaurant < ActiveRecord::Base
      extend FriendlyId
      friendly_id :slug_candidates, use: :slugged

      # Try building a slug based on the following fields in
      # increasing order of specificity.
      def slug_candidates
        [
          :name,
          [:name, :city],
          [:name, :street, :city],
          [:name, :street_number, :street, :city]
        ]
      end
    end

    r1 = Restaurant.create! name: 'Plaza Diner', city: 'New Paltz'
    r2 = Restaurant.create! name: 'Plaza Diner', city: 'Kingston'

    r1.friendly_id  #=> 'plaza-diner'
    r2.friendly_id  #=> 'plaza-diner-kingston'

To use candidates, make your FriendlyId base method return an array. The
method need not be named `slug_candidates`; it can be anything you want. The
array may contain any combination of symbols, strings, procs or lambdas and
will be evaluated lazily and in order. If you include symbols, FriendlyId will
invoke a method on your model class with the same name. Strings will be
interpreted literally. Procs and lambdas will be called and their return values
used as the basis of the friendly id. If none of the candidates can generate a
unique slug, then FriendlyId will append a UUID to the first candidate as a
last resort.

#### Sequence Separator

By default, FriendlyId uses a dash to separate the slug from a sequence.

You can change this with the {FriendlyId::Slugged::Configuration#sequence_separator
sequence_separator} configuration option.

#### Providing Your Own Slug Processing Method

You can override {FriendlyId::Slugged#normalize_friendly_id} in your model for
total control over the slug format. It will be invoked for any generated slug,
whether for a single slug or for slug candidates.

#### Deciding When to Generate New Slugs

As of FriendlyId 5.0, slugs are only generated when the `slug` field is nil. If
you want a slug to be regenerated,set the slug field to nil:

    restaurant.friendly_id # joes-diner
    restaurant.name = "The Plaza Diner"
    restaurant.save!
    restaurant.friendly_id # joes-diner
    restaurant.slug = nil
    restaurant.save!
    restaurant.friendly_id # the-plaza-diner

You can also override the
{FriendlyId::Slugged#should_generate_new_friendly_id?} method, which lets you
control exactly when new friendly ids are set:

    class Post < ActiveRecord::Base
      extend FriendlyId
      friendly_id :title, :use => :slugged

      def should_generate_new_friendly_id?
        title_changed?
      end
    end

#### Locale-specific Transliterations

Active Support's `parameterize` uses
[transliterate](http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-transliterate),
which in turn can use I18n's transliteration rules to consider the current
locale when replacing Latin characters:

    # config/locales/de.yml
    de:
      i18n:
        transliterate:
          rule:
            ü: "ue"
            ö: "oe"
            etc...

    movie = Movie.create! :title => "Der Preis fürs Überleben"
    movie.slug #=> "der-preis-fuers-ueberleben"

This functionality was in fact taken from earlier versions of FriendlyId.

#### Gotchas: Common Problems

FriendlyId uses a before_validation callback to generate and set the slug. This
means that if you create two model instances before saving them, it's possible
they will generate the same slug, and the second save will fail.

This can happen in two fairly normal cases: the first, when a model using nested
attributes creates more than one record for a model that uses friendly_id. The
second, in concurrent code, either in threads or multiple processes.

To solve the nested attributes issue, I recommend simply avoiding them when
creating more than one nested record for a model that uses FriendlyId. See [this
Github issue](https://github.com/norman/friendly_id/issues/185) for discussion.


## History: Avoiding 404's When Slugs Change

FriendlyId's {FriendlyId::History History} module adds the ability to store a
log of a model's slugs, so that when its friendly id changes, it's still
possible to perform finds by the old id.

The primary use case for this is avoiding broken URLs.

### Setup

In order to use this module, you must add a table to your database schema to
store the slug records. FriendlyId provides a generator for this purpose:

    rails generate friendly_id
    rake db:migrate

This will add a table named `friendly_id_slugs`, used by the {FriendlyId::Slug}
model.

### Considerations

Because recording slug history requires creating additional database records,
this module has an impact on the performance of the associated model's `create`
method.

### Example

    class Post < ActiveRecord::Base
      extend FriendlyId
      friendly_id :title, :use => :history
    end

    class PostsController < ApplicationController

      before_filter :find_post

      ...

      def find_post
        @post = Post.find params[:id]

        # If an old id or a numeric id was used to find the record, then
        # the request path will not match the post_path, and we should do
        # a 301 redirect that uses the current friendly id.
        if request.path != post_path(@post)
          return redirect_to @post, :status => :moved_permanently
        end
      end
    end


## Unique Slugs by Scope

The {FriendlyId::Scoped} module allows FriendlyId to generate unique slugs
within a scope.

This allows, for example, two restaurants in different cities to have the slug
`joes-diner`:

    class Restaurant < ActiveRecord::Base
      extend FriendlyId
      belongs_to :city
      friendly_id :name, :use => :scoped, :scope => :city
    end

    class City < ActiveRecord::Base
      extend FriendlyId
      has_many :restaurants
      friendly_id :name, :use => :slugged
    end

    City.friendly.find("seattle").restaurants.friendly.find("joes-diner")
    City.friendly.find("chicago").restaurants.friendly.find("joes-diner")

Without :scoped in this case, one of the restaurants would have the slug
`joes-diner` and the other would have `joes-diner-f9f3789a-daec-4156-af1d-fab81aa16ee5`.

The value for the `:scope` option can be the name of a `belongs_to` relation, or
a column.

Additionally, the `:scope` option can receive an array of scope values:

    class Cuisine < ActiveRecord::Base
      extend FriendlyId
      has_many :restaurants
      friendly_id :name, :use => :slugged
    end

    class City < ActiveRecord::Base
      extend FriendlyId
      has_many :restaurants
      friendly_id :name, :use => :slugged
    end

    class Restaurant < ActiveRecord::Base
      extend FriendlyId
      belongs_to :city
      friendly_id :name, :use => :scoped, :scope => [:city, :cuisine]
    end

All supplied values will be used to determine scope.

### Finding Records by Friendly ID

If you are using scopes your friendly ids may not be unique, so a simple find
like

    Restaurant.friendly.find("joes-diner")

may return the wrong record. In these cases it's best to query through the
relation:

    @city.restaurants.friendly.find("joes-diner")

Alternatively, you could pass the scope value as a query parameter:

    Restaurant.friendly.find("joes-diner").where(:city_id => @city.id)


### Finding All Records That Match a Scoped ID

Query the slug column directly:

    Restaurant.where(:slug => "joes-diner")

### Routes for Scoped Models

Recall that FriendlyId is a database-centric library, and does not set up any
routes for scoped models. You must do this yourself in your application. Here's
an example of one way to set this up:

    # in routes.rb
    resources :cities do
      resources :restaurants
    end

    # in views
    <%= link_to 'Show', [@city, @restaurant] %>

    # in controllers
    @city = City.friendly.find(params[:city_id])
    @restaurant = @city.restaurants.friendly.find(params[:id])

    # URLs:
    http://example.org/cities/seattle/restaurants/joes-diner
    http://example.org/cities/chicago/restaurants/joes-diner


## Translating Slugs Using Simple I18n

The {FriendlyId::SimpleI18n SimpleI18n} module adds very basic i18n support to
FriendlyId.

In order to use this module, your model must have a slug column for each locale.
By default FriendlyId looks for columns named, for example, "slug_en",
"slug_es", etc. The first part of the name can be configured by passing the
`:slug_column` option if you choose. Note that the column for the default locale
must also include the locale in its name.

This module is most suitable to applications that need to support few locales.
If you need to support two or more locales, you may wish to use the
friendly_id_globalize gem instead.

### Example migration

    def self.up
      create_table :posts do |t|
        t.string :title
        t.string :slug_en
        t.string :slug_es
        t.text   :body
      end
      add_index :posts, :slug_en
      add_index :posts, :slug_es
    end

### Finds

Finds will take into consideration the current locale:

    I18n.locale = :es
    Post.find("la-guerra-de-las-galaxias")
    I18n.locale = :en
    Post.find("star-wars")

To find a slug by an explicit locale, perform the find inside a block
passed to I18n's `with_locale` method:

    I18n.with_locale(:es) do
      Post.find("la-guerra-de-las-galaxias")
    end

### Creating Records

When new records are created, the slug is generated for the current locale only.

### Translating Slugs

To translate an existing record's friendly_id, use
{FriendlyId::SimpleI18n::Model#set_friendly_id}. This will ensure that the slug
you add is properly escaped, transliterated and sequenced:

    post = Post.create :name => "Star Wars"
    post.set_friendly_id("La guerra de las galaxias", :es)

If you don't pass in a locale argument, FriendlyId::SimpleI18n will just use the
current locale:

    I18n.with_locale(:es) do
      post.set_friendly_id("La guerra de las galaxias")
    end


## Reserved Words

The {FriendlyId::Reserved Reserved} module adds the ability to exclude a list of
words from use as FriendlyId slugs.

By default, FriendlyId reserves the words "new" and "edit" when this module is
included. You can configure this globally by using {FriendlyId.defaults
FriendlyId.defaults}:

    FriendlyId.defaults do |config|
        config.use :reserved
        # Reserve words for English and Spanish URLs
        config.reserved_words = %w(new edit nueva nuevo editar)
    end

Note that the error message will appear on the field `:friendly_id`. If you are
using Rails's scaffolded form errors display, then it will have no field to
highlight. If you'd like to change this so that scaffolding works as expected,
one way to accomplish this is to move the error message to a different field.
For example:

    class Person < ActiveRecord::Base
        extend FriendlyId
        friendly_id :name, use: :slugged

        after_validation :move_friendly_id_error_to_name

        def move_friendly_id_error_to_name
            errors.add :name, *errors.delete(:friendly_id) if errors[:friendly_id].present?
        end
    end
