# Specification for Project Trellis
Trellis is the code name for the project. 
Note: We were unable to get a reasonable domain name around this idea. We'll get to marketing once the MVP is in place.

## Mission Statement, Objective

Trellis seeks to allow anyone to map significant datasets into a user-defined mental model. Mental model is defined by entities, relationships between entities, and the attributes necessary to describe those entities and relationships. It is assumed that mapping is error-prone and imperfect, requiring correction and tuning. 

## Concept of Operation

A user defines their mental model. The user then provides guidance to the system on where to find content or explicitly uploads content for mapping. The sytem produces candidate information into the mental model structure. The user, aided by the system, then accepts / rejects that content into the model. This acceptance / rejection is used to improve the system's criteria for nominating content. Once comfortable, the user can opt to have the system automatically accept candidate information into the system. 

## Use Cases

Project owner defines their mental model.

Project user provides references to source material to be mapped, most usually in the form of a URL.

A project owner can set a budget of daily fetched URL's. 
A project owner can set a budget of daily processed content (from a URL or upload). 


A provided URL is fetched by the system and processed.

Project user directly uploads material to be mapped - this might be text, a Office document (Word, Excel, PowerPoint), PDF, or an HTML file.



Project owner can later refine that mental model based on learnings.


## Architecture and Design Description

### Script-Based Proof of Concept

1. User provides a text file that contains a list of URL's. 
1. User provides a mental model - built with our existing web application. This is captured as a JSON structure.
1. A "fetch" script exists to fetch each URL and puts the HTML content in a folder. 
1. A "html-strip" script exists to create a new file with just the body content of the HTML, not the head, page header/footer content, any scripts or metadata, and all tags. These will be .txt files.
1. A markdown file exists to provide instructions to the LLM on how to process the content.
1. A "llm-process" script exist that hands the markdown file and iteratively each stripped txt file. This should produce a JSON file for each txt file. This script will have the ability to hit Anthropic or OpenAI models. A CLI parameter will allow us to evaluate differnet models.
1. A "validate-json" exists to check each JSON file produced against the JSON structure/schema file from the mental model. 
1. A "score-json" script will exists to compare and score the quality of the JSON against golden JSON. Perfect score is a match. Missing content or additional content both negatively impact the score. 