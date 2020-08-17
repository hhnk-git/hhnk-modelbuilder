/*
Dit script zet de structuur van de database op in de vorm van schema's. Er worden nog geen tabellen aangemaakt.
De bestaande schema's inclusief alle  tabellen die daar in zitten worden verwijderd.
*/
DROP SCHEMA
IF EXISTS deelgebied CASCADE;
    DROP SCHEMA
    IF EXISTS tmp CASCADE;
        DROP SCHEMA
        IF EXISTS feedback CASCADE;
            CREATE SCHEMA deelgebied;
            CREATE SCHEMA tmp;
            CREATE SCHEMA feedback;