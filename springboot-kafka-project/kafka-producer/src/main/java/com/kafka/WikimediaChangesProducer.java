package com.kafka;


import com.launchdarkly.eventsource.EventHandler;
import com.launchdarkly.eventsource.EventSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.util.concurrent.TimeUnit;

@Service
public class WikimediaChangesProducer {

    private static final Logger LOGGER = LoggerFactory.getLogger(WikimediaChangesProducer.class);

    private KafkaTemplate<String, String> kafkaTemplate;
    public WikimediaChangesProducer(org.springframework.kafka.core.KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void sendMessage() throws InterruptedException {
        String topic = "wikimedia_recentchange";

    //To read ral time stream data from wikimedia, we use "event source"

        // Configurar el manejador de eventos
        EventHandler eventHandler = new WikimediaChangesHandler(kafkaTemplate, topic);

        // Configurar y construir EventSource
        String url = "https://stream.wikimedia.org/v2/stream/recentchange";
        EventSource.Builder builder = new EventSource.Builder(eventHandler, URI.create(url));
        EventSource eventSource = builder.build();

        // Iniciar la conexión EventSource
        eventSource.start();
        //Esperar un minuto antes de cerrar la conexion
        //TimeUnit.MINUTES.sleep(1);
        TimeUnit.SECONDS.sleep(2);
        // Cerrar la conexión EventSource
        eventSource.close();

    }
}

