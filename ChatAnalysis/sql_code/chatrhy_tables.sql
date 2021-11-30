/* Enable warnings*/
\W
SET
  FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS enlace;
DROP TABLE IF EXISTS turno;

CREATE TABLE enlace (
    id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    id_conv INTEGER UNSIGNED NOT NULL,
    rol ENUM('ag', 'cl') NOT NULL DEFAULT 'ag',
    turno_rol SMALLINT UNSIGNED NOT NULL,
    link VARCHAR(300),
    PRIMARY KEY (id)
  );

CREATE TABLE turno (
    id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
    id_conv INTEGER UNSIGNED NOT NULL,
    rol ENUM('ag', 'cl') NOT NULL,
    turno_rol SMALLINT UNSIGNED NOT NULL,
    tokens TEXT(3000) NOT NULL,
    tokens_links TEXT(3000) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (id_conv, rol, turno_rol)
  );

SET
  FOREIGN_KEY_CHECKS = 1;
  /* Disable warnings*/
  \w