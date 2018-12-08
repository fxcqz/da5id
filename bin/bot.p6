#!/usr/bin/env perl6

use lib 'lib';
use Matrix;
use Config;

use Log::Async;
logger.send-to("./da5id.log");


sub MAIN() {
  get-config();
  Matrix::<$room-event-supply>.tap( -> %event {
    info "%event";
  });
  # Matrix::<$session-supply>.tap( -> %session {
  #   for %session<rooms> -> $room {
  #       send-txt-msg(%session, $room, "Sup cunts");
  #   }
  # });
  Matrix::<$msg-supply>.tap( -> %event {
    say %event;
    my %session = %event<session>;
    my $room = %event<room>;
    my %msg = %event<msg>;
    my $sender = %msg<sender>;
    if %msg<content><body>.starts-with(%session<cmd-str>) {
      send-txt-msg(%session, $room, "$sender: Get fucked");
    }
  });

  my $running = init-matrix();
  await $running;

  info "Bot initialised";
}
