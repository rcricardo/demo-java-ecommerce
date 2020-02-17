package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v2"
)

func main() {

	version := "0.0"

	log.Printf("statbetween version %s runtime %s GOMAXPROCS=%s", version, runtime.Version(), strconv.Itoa(runtime.GOMAXPROCS(0)))

	port := ":8888"
	interval := 60 * time.Second

	serversName := os.Getenv("GOBETWEEN_SERVERSNAME")
	if serversName == "" {
		serversName = "sample" // from gobetween config: [servers.sample]
	}
	log.Printf("statbetween GOBETWEEN_SERVERSNAME=[%s] name=[%s] make sure there is a section [servers.%s] in gobetween config", os.Getenv("GOBETWEEN_SERVERSNAME"), serversName, serversName)

	hosts := os.Getenv("GOBETWEEN_HOSTS")

	debug := envDebug("DEBUG")
	log.Printf("statbetween DEBUG=[%s] debug=%v", os.Getenv("DEBUG"), debug)
	log.Printf("statbetween interval: %v", interval)

	list := strings.Fields(hosts)
	size := len(list)
	log.Printf("statbetween hosts: GOBETWEEN_HOSTS=[%s] count: %d", hosts, size)

	if size < 1 {
		log.Printf("statbetween: empty list of hosts: [%s]", hosts)
		os.Exit(1)
	}

	scanHosts(serversName, debug, port, list) // immediate first run

	ticker := time.NewTicker(interval)

	for {
		select {
		case <-ticker.C:
			scanHosts(serversName, debug, port, list)
		}
	}
}

func envDebug(label string) bool {
	deb := os.Getenv(label)
	if deb == "" {
		return false
	}
	b, err := strconv.ParseBool(deb)
	if err != nil {
		log.Printf("statbetween: bad env var %s=[%s]: %v", label, deb, err)
		return false
	}
	return b
}

func scanHosts(serversName string, debug bool, port string, hosts []string) {
	var sumConnTotal, sumConnActive, sumRx, sumTx int

	var countBackends int

	// scan servers
	for _, h := range hosts {
		endpoint := "http://" + h + port + "/servers/" + serversName + "/stats"

		if debug {
			log.Printf("statbetween: opening %s", endpoint)
		}

		body, errGet := httpGet(endpoint)
		if errGet != nil {
			log.Printf("statbetween: http get error %s: %v", endpoint, errGet)
			return
		}

		m := make(map[string]interface{})
		errJson := yaml.Unmarshal(body, &m)
		if errJson != nil {
			log.Printf("statbetween: yaml error %s: %v", endpoint, errJson)
			return
		}

		connActive, _ := m["active_connections"]
		rx, _ := m["rx_total"]
		tx, _ := m["tx_total"]

		countConnActive, _ := connActive.(int)
		countRx, _ := rx.(int)
		countTx, _ := tx.(int)

		if debug {
			log.Printf("statbetween: yaml %s: connActive=%d rx=%d tx=%d", endpoint, countConnActive, countRx, countTx)
		}

		sumConnActive += countConnActive
		sumRx += countRx
		sumTx += countTx

		// scan backends
		b, _ := m["backends"]
		backs, sliceFound := b.([]interface{})
		if !sliceFound {
			log.Printf("statbetween: yaml - not a backend slice: %s: %v", endpoint, b)
			continue
		}
		countBackends += len(backs)
		for _, be := range backs {
			backend, beFound := be.(map[interface{}]interface{})
			if !beFound {
				log.Printf("statbetween: yaml - not a backend map: %s: %v", endpoint, be)
				continue
			}
			host := backend["host"]
			stats := backend["stats"]
			backStats, statsFound := stats.(map[interface{}]interface{})
			if !statsFound {
				log.Printf("statbetween: yaml - not a stats map: %s: %v", endpoint, stats)
				continue
			}

			total, _ := backStats["total_connections"]
			connTotal, _ := total.(int)

			if debug {
				log.Printf("statbetween: yaml %s: host=%s total_connections=%d", endpoint, host, connTotal)
			}

			sumConnTotal += connTotal
		} // scan backends

	} // scan servers

	log.Printf("statbetween: sum: balancers=%d backends=%d connActive=%d connTotal=%d rx=%d tx=%d", len(hosts), countBackends, sumConnActive, sumConnTotal, sumRx, sumTx)

	// curl --header "Content-Type: application/json" --request POST --data '{"host":"teste123xyz","metrica":"xyz","token":"dashajAhs5521jsJa%128","valor":"1.2"}' https://api.monitoring.uoldiveo.com/api/v1/monit

	token := "dashajAhs5521jsJa%128"

	jsonData := fmt.Sprintf(`{"host":"%s","metrica":"%s","token":"%s","valor":"%d"}`, "gobetween", "sumConnTotal", token, sumConnTotal)

	apiPath := "https://api.monitoring.uoldiveo.com/api/v1/monit"

	body, errPost := httpPost(apiPath, "application/json", []byte(jsonData))
	if errPost != nil {
		log.Printf("statbetween: http post error %s: %v postPayload=[%v] responseBody=[%v]", apiPath, errPost, jsonData, string(body))
	}
}

func httpGet(url string) ([]byte, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("httpGet: url=%v: %v", url, err)
	}

	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("httpGet: bad status: %d", resp.StatusCode)
	}

	info, errRead := ioutil.ReadAll(resp.Body)
	if errRead != nil {
		return nil, fmt.Errorf("httpGet: read all: url=%v: %v", url, errRead)
	}

	return info, nil
}

func httpPost(url, contentType string, buf []byte) ([]byte, error) {
	resp, err := http.Post(url, contentType, bytes.NewReader(buf))
	if err != nil {
		return nil, fmt.Errorf("httpPost: url=%v: %v", url, err)
	}

	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("httpPost: bad status: %d", resp.StatusCode)
	}

	info, errRead := ioutil.ReadAll(resp.Body)
	if errRead != nil {
		return nil, fmt.Errorf("httpPost: read: url=%v: %v", url, errRead)
	}

	return info, nil
}
