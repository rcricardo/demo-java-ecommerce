package main

import (
	"fmt"
	"gopkg.in/telegram-bot-api.v4"
	"log"
	"os"
	"strconv"
)

func main() {

	me := os.Args[0]

	if len(os.Args) != 4 {
		log.Printf("usage: %s job build chat", me)
		os.Exit(1)
	}

	token := os.Getenv("BOT_TOKEN")
	if token == "" {
		log.Printf("%s: missing env var BOT_TOKEN", me)
		os.Exit(2)
	}
	log.Printf("%s: found env var BOT_TOKEN", me)

	job := os.Args[1]
	build := os.Args[2]
	chat := os.Args[3]

	chatId, errChat := strconv.ParseInt(chat, 10, 64)
	if errChat != nil {
		log.Printf("%s: bad chat id: %s: %v", me, chat, errChat)
		os.Exit(3)
	}

	bot, errBot := tgbotapi.NewBotAPI(token)
	if errBot != nil {
		log.Printf("%s: failure creating bot client: %v", me, errBot)
		os.Exit(4)
	}

	log.Printf("%s: authorized on account %s", me, bot.Self.UserName)

	format := `UMP - Deploy request:
--
Job: %s
Build: %s
--
To approve:
  /aprovar_deploy_%s__%s
To deny:
  /rejeitar_deploy_%s__%s
`

	text := fmt.Sprintf(format, job, build, job, build, job, build)

	msg := tgbotapi.NewMessage(chatId, text)

	//bot.Debug = true
	bot.Send(msg)
}
