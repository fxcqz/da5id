unit module Matrix;
use Config;
use WWW;
use JSON::Tiny;
use Log::Async;


class Invite is export {
    has Str $.inviter;
    has Str $.channel;
}

my $running-promise = Promise.new;

my $server-supplier = Supplier.new;
our $server-supply = $server-supplier.Supply;

my $session-supplier = Supplier.new;
our $session-supply = $session-supplier.Supply;

my $msg-supplier = Supplier.new;
our $msg-supply = $msg-supplier.Supply;

my $room-event-supplier = Supplier.new;
our $room-event-supply = $room-event-supplier.Supply;

my $id-cnt = 0;


sub get-api-versions($domain) is export {
    my $response = jget($domain.fmt('https://%s/_matrix/client/versions'));
    say($response);
}

sub login(%server) is export {
    info "Logging into server %server";
    my $domain = %server<address>;
    my %login-data := {
        type => "m.login.password",
        user => %server<username>,
        password => %server<password>
    };
    say(%server);
    if %server<deviceid>:exists {
        %login-data<device_id> = %server<deviceid>;
    }
    my %response = jpost("https://$domain/_matrix/client/r0/login",
                         to-json(%login-data));

    %server<token> = %response<access_token>;

    if not %server<deviceid>:exists {
        %server<deviceid> = %response<device_id>;
        update-config();
    }

    my $token = %server<token>;
    my %room-response = jget("https://$domain/_matrix/client/r0/joined_rooms?access_token=$token");
    my @joined = %room-response<joined_rooms>;
    %server<rooms> = @joined;

    $session-supplier.emit(%server);

    return %server;
}

sub sync(%session) is export {
    my $domain = %session<address>;
    if %session<deviceid>:exists {
        %session<device_id> = %session<deviceid>;
    }

    my %response := {};
    if %session<since>:exists {
      %response := jget("https://$domain/_matrix/client/r0/sync?access_token=%session<token>&since=%session<since>");
    } else {
      %response := jget("https://$domain/_matrix/client/r0/sync?access_token=%session<token>");
    }
    say %response;

    my $token = %session<access_token>;
    if %response<next_batch> {
      %session<since> = %response<next_batch>;
    }



    when %response<rooms><join>:exists {
      for %response<rooms><join>.kv -> $room-id, %room-data {
        my @events := %room-data<timeline><events>;
        say to-json(%room-data<timeline>);
        #
        # info "Evts {@events[0]}";
        # info "Events var {@events.^name}";
        # info "Events[0] {@events[0].^name}";
        # info "Events[0][0] {@events[0][0].^name}";
        if not @events[0].^name ~~ "Hash" {
          @events := @events[0];
        }

        for @events -> %event {
          info "room-dat: {%event<event_id>}, type: {%event.^name}";
          $room-event-supplier.emit({
            session => %session,
            room => $room-id,
            event => %event,
          });
        }
      }
    }
    #
    # when %response<rooms><invite>:exists {
    #   for %response<rooms><invite>.kv -> $room-id, %invite {
    #     join-room(%session, $room-id);
    #   }
    # }
}

sub join-room(%session, $room) {
  my $domain = %session<address>;
  my $token = %session<token>;
  my %response := jpost("https://$domain/_matrix/client/r0/rooms/$room/join?access_token=$token",
                  to-json({}));
}

sub send-msg(%session, $room, %msg) {
    my $domain = %session<address>;
    my $token = %session<token>;
    my $mid = $id-cnt++;
    my $url = "https://$domain/_matrix/client/r0/rooms/$room/send/m.room.message/$mid?access_token=$token";
    info "Sending message {%msg}";
    my %response := jpost($url, to-json(%msg));
}

sub send-txt-msg(%session, $room, $text) is export {
  my %msg := {
        msgtype => "m.text",
        body => $text,
  };
  send-msg(%session, $room, %msg)
}


# TODO: Make invite tap/supply work
# suppy supplies Invites
#my $event-tap = sub (%session,

sub init-matrix() is export {
  $server-supply.tap( -> $server {
    login($server)
  });
  $session-supply.tap( -> %session {
    %session<sync-schedule> = Supply.interval(1).tap({
      sync(%session);
    });
  });

  $room-event-supply.tap( -> %vars {
    my %session = %vars<session>;
    my %event = %vars<event>;
    if %event<type> ~~ "m.room.message" {
      $msg-supplier.emit({
        session => %session,
        msg => %event
      });
    }
  });
  my @servers := %config<servers>;
  for @servers {
    $server-supplier.emit($_);
  }

  return $running-promise;
}
