package com.kafka;

import com.kafka.entity.WikimediaData;
import com.kafka.repository.WikimediaDataRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class KafkaConsumerDatabase {

    private final Logger LOGGER = LoggerFactory.getLogger(KafkaConsumerDatabase.class);

    private WikimediaDataRepository dataRepository;

    public KafkaConsumerDatabase(WikimediaDataRepository dataRepository) {
        this.dataRepository = dataRepository;
    }

    @KafkaListener(topics = "wikimedia_recentchange",
                    groupId = "myGroup"
    )
    public void consume(String eventMessage){
        LOGGER.info(String.format("Event message recieved -> %s", eventMessage));

        WikimediaData wikimediaData = new WikimediaData();
        wikimediaData.setWikiEventData(eventMessage);

        dataRepository.save(wikimediaData);

    }
}
