
#!/usr/bin/env perl
# Basic Telegram Bot implementation using WWW::Telegram::BotAPI
use strict;
use warnings;
use WWW::Telegram::BotAPI;
use Try::Tiny;
use utf8;
use feature 'say';

my $api = WWW::Telegram::BotAPI->new (
    #token => (shift or die "ERROR: a token is required!\n")
    token => ($ENV{TELEGRAM_TOKEN} or die "ERROR: a token is required!\n")
);

# Bump up the timeout when Mojo::UserAgent is used (LWP::UserAgent uses 180s by default)
$api->agent->can ("inactivity_timeout") and $api->agent->inactivity_timeout (45);
my $me = $api->getMe or die;
my ($offset, $updates) = 0;

# The commands that this bot supports.
my $pic_id; # file_id of the last sent picture
my $reply_to_message = "Ваш выбор?";
my $commands = {
    # Example demonstrating the use of parameters in a command.
    #"say"      => sub { join " ", splice @_, 1 or "Использование: /say что-нибудь" },
    # Example showing how to use the result of an API call.
    # "whoami"   => sub {
    #     sprintf "Приветствую %s, я %s! Как поживаете?", shift->{from}{username}, $me->{result}{username}
    # },
    # Example showing how to send multiple lines in a single message.
    "knock"    => sub {
        sprintf "Тук-тук.\n- Кто здесь?\n- @%s!", $me->{result}{username}
    },
    # Example displaying a keyboard with some simple options.
    # "keyboard" => sub {
    #     +{
    #         text => "Это незамысловатая клавиатура.",
    #         reply_markup => {
    #             keyboard => [ [ "a" .. "c" ], [ "d" .. "f" ], [ "g" .. "i" ] ],
    #             one_time_keyboard => \1 # \1 maps to "true" when being JSON-ified
    #         }
    #     }
    # },
    
    "vote" => sub {
        +{
            text => "Ваш выбор?",
            reply_markup => {
                keyboard => [ [ "Да" , "Нет" , "Ого!" ], [ "😜" , "🤔" , "👊" ] ],
                one_time_keyboard => \1 # \1 maps to "true" when being JSON-ified
            }
        }
    },

    # Let me identify yourself by sending your phone number to me.
    # "phone" => sub {
    #     +{
    #         text => "Номер телефона оставите?",
    #         reply_markup => {
    #             keyboard => [
    #                 [
    #                     {
    #                         text => "Конечно!",
    #                         request_contact => \1
    #                     },
    #                     "Остань!"
    #                 ]
    #             ],
    #             one_time_keyboard => \1
    #         }
    #     }
    # },
    # Test UTF-8
    "encoding" => sub { "Привет! こんにちは! Buondì!" },
    "contacts" => sub { "Консультации по телефону +375299807993\nСайт федерации воркаут - http://workout-federation.org/\nГруппа тренировок вконтакте - https://vk.com/training_strength_workout\nYouTube - https://www.youtube.com/channel/UCDRdzEzZAPP-at5fFPHK-KQ" },
    "schedule" => sub { "Пн - \nВт - 18:00\nСр - \nЧт - 18:00\nПт - 18:00\nСб - 16:00\nВс - 16:00"},
    # Example sending a photo with a known picture ID.
    "lastphoto" => sub {
        return "Вы не отправляли изображений!" unless $pic_id;
        +{
            method  => "sendPhoto",
            photo   => $pic_id,
            caption => "Вот!"
        }
    },
    "_unknown" => "Неизвестная команда :( Используйте /start"
};

# Generate the command list dynamically.
my $howHelp = "\n
Нам нужна ваша помощь!

Свою общественную деятельность Молодежная Федерация воркаут ведет абсолютно бесплатно, но для самих эта работа обходится не дешево!!! Будем признательны Вам за любую посильную помощь в нашем ОБЩЕМ ДЕЛЕ…

Мы нуждаемся в:
 - помещении для спортзала, (для проведения бесплатных тренировок и подготовки сборной Беларуси по воркауту)
 - мобильной площадке, для проведения мероприятий
 - микроавтобусе, для перевозки на мероприятия мобильной площадки, звукового оборудования
 - снаряжении (гантели, петли trx, резиновые петли, скакалки)
 - сертифицированных инструкторах и лекторах
 - принтере, сканере, компьютере
 - майках, головных уборах, спортивных костюмах с фирменным стилем, для активных участников нашего движения
 - грамотах, медалях, призах, для участников различных конкурсов
 - Вашей рекламной поддержке и добром слове
";
$commands->{start} = "Приветствую! Используйте /" . join " - /", grep !/^_/, keys %$commands, $howHelp;
$commands->{help}  = "Приветствую! Используйте /" . join " - /", grep !/^_/, keys %$commands, $howHelp;

# Special message type handling
my $message_types = {
    # Save the picture ID to use it in `lastphoto`.
    "photo" => sub { $pic_id = shift->{photo}[0]{file_id} },
    # Receive contacts!
    "contact" => sub {
        my $contact = shift->{contact};
        +{
            method     => "sendMessage",
            parse_mode => "Markdown",
            text       => sprintf (
                            "Контактные данные.\n" .
                            "- Имя: *%s*\n- Фамилия: *%s*\n" .
                            "- Номер телефона: *%s*\n- Telegram UID: *%s*",
                            $contact->{first_name}, $contact->{last_name} || "?",
                            $contact->{phone_number}, $contact->{user_id} || "?"
                        )
        }
    }
};

printf "Приветствую! Я %s. Запускаюсь...\n", $me->{result}{username};

while (1) {
    $updates = $api->getUpdates ({
        timeout => 30, # Use long polling
        $offset ? (offset => $offset) : ()
    });
    unless ($updates and ref $updates eq "HASH" and $updates->{ok}) {
        warn "WARNING: getUpdates returned a false value - trying again...";
        next;
    }
    for my $u (@{$updates->{result}}) {
        $offset = $u->{update_id} + 1 if $u->{update_id} >= $offset;
	printf "Update ID: %s, Message ID: %s\n", $u->{update_id}, $u->{message}{message_id};
	my $reply_to_message_text = $u->{message}{reply_to_message}{text};
	if ($reply_to_message_text == $reply_to_message) {
		printf "Remove keyboard '%s' for user '%s'\n", $reply_to_message, $u->{message}{from}{username};
		$api->api_request('sendMessage', {
				chat_id => $u->{message}{chat}{id},
				reply_markup => {
						remove_keyboard => \1
				},
				selective => \1,
				username => $u->{message}{from}{username},
				text => "Голос принят."
		});
	}
        if (my $text = $u->{message}{text}) { # Text message
            printf "Incoming text message from \@%s\n", $u->{message}{from}{username};
            printf "Text: %s\n", $text;
            next if $text !~ m!^/[^_].!; # Not a command
            my ($cmd, @params) = split / /, $text;
	    $cmd =~ s/\@$me->{result}{username}//g;
            my $res = $commands->{substr ($cmd, 1)} || $commands->{_unknown};
            # Pass to the subroutine the message object, and the parameters passed to the cmd.
            $res = $res->($u->{message}, @params) if ref $res eq "CODE";
            next unless $res;
            my $method = ref $res && $res->{method} ? delete $res->{method} : "sendMessage";
            try {
		$api->$method ({
		    chat_id => $u->{message}{chat}{id},
		    ref $res ? %$res : ( text => $res )
			       });
		print "Reply sent.\n";
	    } catch {
		warn "caught error: $_";
	    }
        }
        # Handle other message types.
        for my $type (keys %{$u->{message} || {}}) {
            next unless exists $message_types->{$type} and
                        ref (my $res = $message_types->{$type}->($u->{message}));
            my $method = delete ($res->{method}) || "sendMessage";
            $api->$method ({
                chat_id => $u->{message}{chat}{id},
                %$res
            })
        }
    }
}
