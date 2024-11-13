Deze directory bevat de publicatiepunten van data.vlaanderen.be productie branch op dit moment: https://github.com/Informatievlaanderen/Data.Vlaanderen.be/tree/cf1b8abc2d49d35d8cb513638a8a6a319fd4701a/config/production


Er zijn 3 subdirectories die overeenkomen met werkprioriteiten.
De checks te conformiteit voor toolchain 4 worden in volgorde van de prioteit uitgevoerd.
Eerst prio1, dan prio2, vervolgens prio3 en tenslotte de overblijvende in deze directory.


Stappen plan:

1. kies een publicatiepunten file om te valideren.
2. verwijder de gekozen file uit deze directory en copieer die naar de dev directory.
3. Doe de noodzakelijke aanpassingen.
4. Indien tevreden copieer de file naar rollout4-checked directory

De laatste stap is er om te zorgen dat we zo mogelijks de doorvoorsnelheid kunnen verhogen omdat dan het risico op reprocessing van publicatiepunten vermeden wordt.


Aandachtspunten:
1. controleer ook of de keten van publicatiepunten verbonden is. Indien niet probeer dat goed te zetten.
2. controleer of er een versieloze publicatiepunt is. Indien niet maak er een aan.
3. het bevriezen van oude publicatiepunten kunnen we met scripting doen: Fouten in deze punten kunnen genegeerd worden. 
   Focus dus op de laatste (de gepubliceerde versie) om deze door de tooling te krijgen.



