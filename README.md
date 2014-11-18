## KnownTroll

KnownTroll is a collaborative blocking application for Twitter, which allows users to create blocklists and share them with their friends.

The first version of KnownTroll was built for the [2014 Rails Rumble](http://railsrumble.com/), a competition where entrants must build a [Ruby on Rails](http://rubyonrails.org/) application in 48 hours. This version has been debugged and comes with a full test suite.

Rails Rumble required participants to deploy their applications to [Heroku](https://www.heroku.com/), so KnownTroll was written with Heroku in mind.

## Why is KnownTroll open-source?

KnownTroll is open-source because I'm unlikely to devote much additional time to it, because other people might find it useful, and because running it on Heroku is (unfortunately) not particularly cheap.

People looking to use KnownTroll may want to look at Jacob Hoffman-Andrews' excellent [BlockTogether](https://blocktogether.org/), which is [also open source](https://github.com/jsha/blocktogether) and has additional functionality which KnownTroll does not.

## Running KnownTroll locally

KnownTroll is a Rails application and is set up and run like many other Rails applications.

KnownTroll uses Postgres (a Heroku requirement), so you'll need to have postgres installed and create production and test databases. Edit `config/database.yml` as you like.

KnownTroll uses the Twitter API, so you'll want to create a couple Twitter applications over at [Twitter's developer portal](https://apps.twitter.com/) - one for development, and one for production. You'll need both their API Key and API Secret.

KnownTroll uses the [Figaro](https://github.com/laserlemon/figaro) gem to manage its secrets, which are stored in a `config/application.yml` file that you'll have to create. Mine looks something like this:

```ruby
twitter_key: TWITTER_API_KEY_FOR_DEVELOPMENT_APPLICATION
twitter_secret: TWITTER_API_SECRET_FOR_DEVELOPMENT_APPLICATION

delayed_job_web_username: USERNAME_FOR_DELAYED_JOB_WEB_CONSOLE
delayed_job_web_password: PASSWORD_FOR_DELAYED_JOB_WEB_CONSOLE

production:
  twitter_key: TWITTER_API_KEY_FOR_PRODUCTION_APPLICATION
  twitter_secret: TWITTER_API_SECRET_FOR_PRODUCTION_APPLICATION
```

(The delayed_job_web entries are the username and password used for accessing the [delayed_job_web console](https://github.com/ejschmitt/delayed_job_web) in production, which can be reached from at http://yourdomain.com/delayed_job.)

KnownTroll requires more than a single web process to run - it also requires a background worker and a clock process to handle scheduling. KnownTroll therefore uses a `Procfile` and the [foreman](https://github.com/ddollar/foreman) gem to run. Start KnownTroll with the following command:

`foreman start -f Procfile.local`

Note that I use a local Procfile because I start up the postgres database simultaneously with my application - something I need to do locally but not in production, where Heroku takes care of postgres for me. If you keep postgres running all the time in the background, like a lot of developers do, you can get rid of the `Procfile.local` file and just start the application with `foreman start`.

## Running KnownTroll on Heroku

Unfortunately, it's not possible to run an instance of KnownTroll on Heroku for free.

First, you'll need to run everything over HTTPS, so people don't intercept your users' oauth tokens and take over their Twitter accounts. To do this, you'll need to buy an SSL certificate (around $10/year at the right place) and [set up an SSL endpoint](https://devcenter.heroku.com/articles/ssl-endpoint) on Heroku (which at the moment, $20/month).

Next, you'll need to set up some Heroku instances to run KnownTroll's background tasks (explained in more depth below, but yes, you'll need them). Heroku doesn't allow for standard cron jobs, so KnownTroll uses clockwork and delayed_job to schedule background tasks on Heroku - [here's how we do it](https://devcenter.heroku.com/articles/clock-processes-ruby). Note that this requires both an additional clock instance and an additional worker instance, and those are currently $35/month each.

Finally, although I've made some deliberate design decisions to keep the number of rows in the database low, you're almost certainly going to need a bigger database than the free hobby-basic one. [Upgrading to the hobby-dev database](https://devcenter.heroku.com/articles/upgrading-heroku-postgres-databases) will cost $9/month.

I'm sure it's possible to run KnownTroll for less elsewhere, with just a little modification. I built KnownTroll for Heroku because Rails Rumble required it.

Anyhow - once you've set up your SSL endpoint and everything else, running KnownTroll on Heroku isn't much different than running any other application. You just have to remember to turn on the clock and worker processes by running these commands from your terminal:

```
heroku ps:scale clock=1
heroku ps:scale worker=1
```

Don't forget to run `figaro heroku:set -e production` to transfer the secrets in `application.yml` to Heroku!

## About the KnownTroll software

### General Principles

1. No one else can do anything to block someone who a user has explicitly followed.
2. No one else can do anything to unblock someone who a user has explicitly blocked.
3. No user is aware of any other user, or any list created by another user, unless they mutually follow each other.

The third principle is the controversial one - after all, users might want to create public blocklists for sharing, or find and subscribe to lists not created by people they're mutually following. I decided on it in part because I didn't want KnownTroll itself to be used for trolling, via the creation of blocklists designed only to offend others. I also didn't want anyone's use of KnownTroll to make them a target for additional trolling.

Of course, it's perfectly possible to fork KnownTroll and modify it get rid of this third principle.

### General KnownTroll operation

KnownTroll users authenticate using OAuth, authorizing KnownTroll to read and write to their Twitter account. They then select subsets of the accounts they've blocked on Twitter and turn them into blocklists, which are visible to their 'friends' - users of KnownTroll that mutually follow each other on Twitter.

KnownTroll users can subscribe to any blocklists they have access to. When they do so, the Twitter accounts on that blocklist are automatically blocked from their own account - not instantaneously, but over time, since the Twitter API is rate-limited. When the creator edits their blocklist by adding or removing accounts, subscribers to that blocklist will have those accounts blocked or unblocked automatically.

Unsubscribing to a blocklist reverses the process - all accounts on the blocklist gradually become unblocked, unless they've been blocked by a subscription to another blocklist or the user directly.

Everything is kept in sync through background tasks, which periodically call the Twitter API and check for updates.

### The KnownTroll database

KnownTroll has four important tables - the User table, the List table, the Troll table, and the Blockqueue table.

#### The User table

A KnownTroll user is a Twitter user that's decided to use KnownTroll.

In the `User` model, the `access_token` and `access_secret` fields contain the passwords we need to make API requests on their behalf - we get them when we authorize the app using Twitter. If the user deauthorizes, the API will return an error, and we'll wipe out the `access_token` and `access_secret`, making them reauthorize to use the app again.

A user has many lists. In our vocabulary, we say a user has 'subscribed' to a list. These lists (which are described in detail below) each have many trolls.

Users have a field called a `block_list`, which contains a serialized array of Twitter IDs. The `block_list` is a local copy of the Twitter users blocked by this user -- all of them, whether blocked directly by the user or caused by subscribing to another user's list. This local copy is periodically updated by a background task.

Users also have field called `own_blocks`, which contains a serialized array of Twitter IDs. The `own_blocks` field holds Twitter users we believe this user has manually blocked - that is, we know they weren't blocked thanks to subscribing to another user's list. Note that we can't get this directly from Twitter - this is our best guest based on the accounts the user's got blocked and the block lists the user's subscribed to.

A user has a field called a `friend_list`, which contains a serialized array of Twitter IDs. The `friend_list` is a local copy of the Twitter users followed by this user. Like the `block_list`, the `friend_list` is periodically updated by a background task.

Why are we storing serialized arrays instead of, say, setting up a Friend model with an ActiveRecord relation to the User model? It's because Heroku's relatively inexpensive ($9/month) database is limited to 10 million rows, and KnownTroll was built to be deployed on Heroku. Storing serialized arrays keeps the row count lower.

#### The List table

Lists are created by KnownTroll users and are a subset of the trolls in the user's `own_blocks` list.

Lists have a name and a description, which are set by the list's creator. Each list also has an `owner_id` - the user ID of the creator. Most importantly, lists have a field called a `block_list`, which contains a serialized array of Twitter IDs, selected by the list's creator.

Lists have and belong to many users -  if a user belongs to a list (aka 'is subscribed to a list'), KnownTroll will systematically block every troll on that list from the user's Twitter account.

Lists also have a boolean `auto_add_new_blocks` flag, which is set by the list's creator. If set to true, when the creator blocks an account on Twitter that account will automatically be added to the list.

#### The Troll table

Trolls are local copies of Twitter accounts that have been blocked by one of KnownTroll's users.

We store a few fields on the troll model - `name`, `screen_name`, an `image_url` - so the troll can be visually identified when adding the troll to a list.

When a user is first created, we create a Troll for every account the user has blocked. While we fetch complete details for the first hundred trolls on user creation, we fetch details for the rest in a background task. (Otherwise user creation would take far too long for users blocking thousands of accounts.) The boolean `checked` flag and `last_checked` timestamp are used by that background task.

Trolls are often (although not often enough!) suspended or deleted by Twitter. When this happens, we set the `suspended` or `notfound` boolean flags to `true` and no longer attempt API calls on them - which keeps us from trying to perpetually retrieve their information / issue blocks for them.

#### The Blockqueue table

The Blockqueue holds pending block and unblock actions, which KnownTroll's background tasks take and work with.

Each item in the Blockqueue has a `task` field, which is an enum with two possible values - 'block' or 'unblock'. Each item also has a `user_id` - the Twitter ID of the account we're working with - as well as a `troll_id` - the Twitter ID of the account we're blocking or unblocking.

For understanding how the Blockqueue gets filled with tasks, see the 'Business Logic' section of the documentation.

### KnownTroll's Business Logic

* When initializing a new user:
    * We write the user's friend_list with friend ids.
    * We write the user's block_list with blocked ids.
    * We also write the user's own_blocks with blocked ids.

* When creating a new list:
    * No additional business logic here, woo hoo!

* When adding trolls to a list:
    * We update the list's block_list to include the new trolls.
    * For each user subscribed to the list:
        * For each troll added to the list:
            * See the block logic (user / troll).

* When removing trolls from a list:
    * We update the list's block_list to no longer include the new trolls.
    * For each user subscribed to the list:
        * For each troll removed from the list:
            * See the unblock logic (user / troll).

* When deleting a list:
    * For each user subscribed to the list:
        * For each troll on the list:
            * See the unblock logic (user / troll).
        * We remove the list from the user's subscribed lists.
        * We remove the list.

* When subscribing to a list:
    * We add the list to the user's subscribed lists.
    * For each troll on the list:
        * See the block logic (user / troll).

* When unsubscribing from a list:
    * We remove the list from the user's subscribed lists.
    * For each troll on the list:
        * See the unblock logic (user / troll).

* When syncing trolls with BlocksRefreshJob:
    * We overwrite the user's block_list with the new blocked_ids.
    * For each new troll that appears:
    * If the troll is on one of the user's subscribed-to lists:
        * We do nothing. (The user blocked that troll because of KnownTroll.)
    * If the troll is not on one of the user's subscribed-to lists:
        * We add the new troll to the user's own_blocks. (The user blocked that troll manually.)
            * For each list owned by that user and auto-subscribed to new blocks:
                * We add the new troll to that list.
                * For each user subscribed to that list:
                    * See the block logic (user / new troll).
    * For each troll that has been removed:
    * If the troll is in the own_blocks:
        * We remove the troll from the own_blocks.
        * If the troll is also on one of the user's owned lists:
            * For each owned list the troll is on:
                * We remove the troll from that list's block_list.
                * For each subscriber to that list:
                    * See the unblock logic (subscriber / troll).
        * If the troll is not on any of the user's owned lists:
            * We do nothing further.
    * If the troll is not in the own_blocks:
        * We do nothing. (The user has unblocked a user that KnownTroll has blocked. That user can stay unblocked.)

* When syncing friends with FriendsRefreshJob:
    * We overwrite the user's friend_list with the new friend_ids.
    * For each new friend that appears:
        * We do nothing. (If the friend is on the user's own_blocks / block list, it will be removed at next sync.)
    * For each removed friend:
        * If the removed friend is also a troll in KnownTroll:
            * If the troll is on any lists the user has subscribed to:
                * We add that troll / user to the blockqueue to be blocked.
        * If the troll is not on any lists we've subscribed to:
            * We do nothing further.
    * If the removed friend is also a user in KnownTroll:
        * If the user is subscribed to any of the removed friend's owned lists:
            * For each owned list the user is subscribed to:
                * We remove that list from the user's subscribed lists.
                * For each troll on that list:
                    * See the unblock logic (user / troll).
        * If the removed friend is subscribed to any of the user's owned lists:
            * For each owned list the removed friend is subscribed to:
                * We remove that list from the removed friend's subscribed lists.
                    * For each troll on that list:
                        * See the unblock logic (removed friend / troll).

* Block logic (user / troll):
    * If the troll is on the user's friend_list:
        * We do nothing. (That user decided to follow the troll, so it cannot be blocked.)
    * If the troll is not on the user's friend_list:
        * We add that troll / user to the blockqueue to be blocked.

* Unblock logic (user / troll):
    * If the user now has that troll in another subscribed list or their own_blocks:
        * We do nothing. (The troll is still blocked from another source.)
    * If the user no longer has that troll in another subscribed list or their own_blocks:
        * We add that user / troll to the blockqueue to be unblocked.

### KnownTroll Background Tasks

Background tasks are kicked off by the `clockwork` gem running the contents of `lib/clock.rb`. If you look in `lib/clock.rb`, you'll see four background tasks, which get added to the delayed_job queue at regular intervals:

* TrollUpdateJob - runs every minute
* BlockJob - runs every three minutes
* BlocksRefreshJob - runs every fifteen minutes
* FriendsRefreshJob - runs every fifteen minutes

None of these jobs will be added to the delayed_job queue if it's already got a job of that type in there - since each of the jobs do the same sort of thing every time, we don't need to keep multiple instances of the same job lurking around in the queue.

The jobs themselves are all in the `app/jobs` directory.

#### TrollUpdateJob

The TrollUpdateJob first gets the Twitter IDs of up to a hundred trolls without names / screen names / avatar images. If there aren't any, it fetches the Twitter IDs of up to a hundred trolls that haven't been checked for updates in the past twenty-four hours. If there aren't any of *those*, it ends.

Assuming it's got some IDs, it calls the Twitter API and updates our local troll information to match - so names / screen names / avatar images are kept up to date. If any trolls have been deleted or suspended, it marks them accordingly so we also aren't trying to update them.

##### BlockJob

The BlockJob fetches tasks (the pending blocks or unblocks) from the Blockqueue table and performs them. We only fetch one task from the queue per KnownTroll user, so we don't run into rate-limiting issues with the Twitter API. We also will only perform one task per KnownTroll troll, because Twitter frowns on too many automated blocks simultaneously. (For a discussion of these issues, see [this email exchange with Twitter](http://www.oolon.co.uk/?p=553), which I took note of when writing this software.)

Once the BlockJob has fetched a list of tasks from the blockqueue, it calls the Twitter API to block / unblock as needed. If there's no tasks in the Blockqueue, of course, it doesn't do anything.

I've been conservative by setting the BlockJob to run every three minutes - it could probably run once every two minutes. The limiting factor is the Twitter API's rate-limiting - for blocking and unblocking, no more than fifteen calls in fifteen minutes, including, I believe, those made in other applications.

#### BlocksRefreshJob

The BlocksRefreshJob calls the Twitter API and updates the `block_list` for each user in turn.

It then takes any necessary actions - removing trolls from lists if they've been manually unblocked, adding new trolls to lists if the lists are set up to automatically receive new trolls, and so on.

See the 'Business Logic' section of the documentation for full details, beginning with 'When syncing trolls with BlocksRefreshJob'.

#### FriendsRefreshJob

The FriendsRefreshJob calls the Twitter API and updates the `friend_list` for each user in turn.

It then takes any necessary actions - for example, unsubscribing users from lists if they're no longer mutual friends with the list owner.

See the 'Business Logic' section of the documentation for full details, beginning with 'When syncing friends with FriendsRefreshJob'.

### KnownTroll's 'Demo' section

For RailsRumble, I decided to create a 'demo' so judges who didn't want to sign up using their Twitter accounts could still see the functionality. The demo - built quickly at the last minute - consists mostly of code copied over from the lists controller and filled with fake data, and therefore is terribly un-DRY. If you should change your views, the demo itself won't update.

The following directories and files are for the demo and can be safely removed should you not want to bother offering a demo:

* `app/controllers/demo/`
* `app/views/demo/`
* `app/views/layouts/_demobar.html.slim`
* `app/views/lauouts/demo.html.slim`
* the `namespace :demo` portion of `config/routes.rb`

### Testing KnownTroll and Viewing Test Coverage

KnownTroll is covered well by unit and functional tests. KnownTroll doesn't have any end-to-end integration tests, however - you may wish to write some before dramatically altering the views.

To run KnownTroll's test suite, simply run `rspec` from the KnownTroll directory.

KnownTroll uses the [simplecov gem](https://github.com/colszowka/simplecov) to measure test coverage. After running the test suite, open `coverage/index.html` to see a detailed report on test coverage, including lines of code not tested.

The only thing of note in the test suite is the use of a small Sinatra application - `spec/support/fake_twitter.rb` - to handle requests to the Twitter API. Mocked responses to API calls are found in the `spec/support/fixtures` directory.

Special cases - for instance, returning errors - are handled within each test by setting the user's `access_token` to a special constant. The Sinatra application detects this constant in `request.env["HTTP_AUTHORIZATION"]` and returns the response specific to the special case.

### KnownTroll's Limitations

At the moment, KnownTroll can't handle accounts who are blocking or following more than 75,000 accounts. This is because of the rate-limiting restrictions on the Twitter API - KnownTroll can only fetch the identifiers of 5,000 accounts at a time, and can do this only 15 times in rapid succession before Twitter stops returning valid data and starts returning errors.

Ideally, KnownTroll would fetch and create the IDs of trolls / followers in a background task, accomodating these large users. At the moment, KnownTroll marks the new user as `oversized` (by setting a boolean flag) and explains the situation to them with a message.

KnownTroll's UI is not optimized for users with many thousands of blocked accounts - when creating a list, we load information about every one of these accounts on a single page. This works fine if you're blocking a few hundred people but is unwieldly and slow if you're blocking thousands.

Ideally, KnownTroll would have some proper pagination.

At the moment, once KnownTroll gets an error message from the Twitter API that indicates a troll has been suspended or deleted, we set a boolean flag on that troll and never do anything with it ever again. (The Twitter API returns an error whenever we try to do something with a suspended / deleted user, and we want to minimize errors.)

The problem: if a suspended user becomes *unsuspended* (which I believe happens only very rarely), we won't learn about this. Ideally, KnownTroll would (very occasionally) check to see if suspended users have become unsuspended.

At the moment, KnownTroll only uses the Twitter REST API. It does not use the Twitter Streaming API. This means updates can be a little on the slow side - delayed as long as fifteen minutes. If KnownTroll used the Twitter Streaming API, it would be notified right away when a user blocked a troll, allowing updates to block lists to occur much faster.

## LICENSE

This projected is licensed under the terms of the MIT license.

See LICENSE.md for the full license file.