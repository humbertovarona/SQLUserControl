CREATE DATABASE IF NOT EXISTS UC;

CREATE USER IF NOT EXISTS uUC@10.12.40.120 IDENTIFIED BY PASSWORD 'YOUR-PASSWD';
GRANT ALL PRIVILEGES ON UC.* TO uUC@10.12.40.120;
FLUSH PRIVILEGES;               

USE UC; 

###
### Suma de chequeo de registros
###
DROP FUNCTION IF EXISTS encCRC;
DELIMITER //
CREATE FUNCTION encCRC(str_to_cript varchar(256)) RETURNS varchar(41)
BEGIN
  DECLARE temp_hash varchar(41);
  SET temp_hash='YOUR-HASH';
  
  RETURN temp_hash;
END
//
DELIMITER ; 

DROP TABLE IF EXISTS bitacora;
CREATE TABLE IF NOT EXISTS bitacora (
  codigo_bitacora BIGINT NOT NULL,
  nivel  BIGINT NOT NULL,
  descripcion VARCHAR(128) DEFAULT NULL,
  fecha DATETIME,
  hash_bitacora VARCHAR(41),
  PRIMARY KEY(codigo_bitacora)
);

###
### Insertar registro en la bitacora
###
DROP PROCEDURE IF EXISTS insert_registro;
DELIMITER //
CREATE PROCEDURE insert_registro(niv BIGINT, descr VARCHAR(35))
BEGIN
  DECLARE RegCount bigint DEFAULT 0;
  DECLARE temp_hash VARCHAR(41);
  DECLARE temp_fecha VARCHAR(10);
  SELECT COUNT(*) FROM bitacora INTO RegCount;
  SELECT RegCount+1 INTO RegCount;
  SELECT DATE_FORMAT(NOW(),'%d/%m/%Y %HH:%ss') INTO temp_fecha;
  SET temp_hash=encCRC(CONCAT(CONVERT(RegCount, UNSIGNED), CONVERT(niv, UNSIGNED), descr, temp_fecha));
  INSERT INTO bitacora(codigo_bitacora, nivel, descripcion, fecha, hash_bitacora) VALUES (RegCount, niv, descr, NOW(), temp_hash);
END;
//
DELIMITER ;


DROP VIEW  v_logs_mes_actual;
CREATE VIEW v_logs_mes_actual 
AS 
SELECT nivel, descripcion, fecha FROM bitacora WHERE MONTH(fecha)=MONTH(CURDATE());

DROP VIEW  v_logs_mes_anterior;
CREATE VIEW v_logs_mes_anterior
AS
SELECT nivel, descripcion, fecha FROM bitacora WHERE MONTH(fecha)=MONTH(DATE_ADD(CURDATE(),INTERVAL -1 MONTH));
 

DROP TABLE IF EXISTS usuarios;
CREATE TABLE IF NOT EXISTS usuarios (
  codigo_usuario bigint NOT NULL,
  nombre VARCHAR(15) DEFAULT NULL,
  pw VARCHAR(41) DEFAULT NULL,
  tipo_de_usuario TINYINT,
  hash_user varchar(41),
  PRIMARY KEY(codigo_usuario)
);


DROP VIEW  v_usuarios;
CREATE VIEW v_usuarios 
AS 
SELECT nombre, tipo_de_usuario FROM usuarios;


###
### Insertar un usuario
###
DROP FUNCTION IF EXISTS insert_usuario;
DELIMITER //
CREATE FUNCTION insert_usuario(unombre varchar(50), upw varchar(41), tusuario TINYINT) RETURNS TINYINT
BEGIN
  DECLARE existe TINYINT DEFAULT 0;
  DECLARE userCount bigint DEFAULT 0;
  DECLARE temp_hash VARCHAR(41);
  SELECT COUNT(nombre) FROM usuarios WHERE nombre=unombre INTO existe;
  IF existe=0 THEN
    SELECT COUNT(*) FROM usuarios INTO userCount;
    SELECT userCount+1 INTO userCount;
    SET temp_hash=encCRC(CONCAT(unombre,CONVERT(userCount, UNSIGNED),CONVERT(tusuario, UNSIGNED)));
    INSERT INTO usuarios (codigo_usuario, nombre, pw, tipo_de_usuario, hash_user) VALUES (userCount, unombre, PASSWORD(upw), tusuario, temp_hash);
  END IF; 
  RETURN existe;
END;
//
DELIMITER ;



###
### Chequea la integridad de la tabla usuarios
###
DROP FUNCTION IF EXISTS ch_integrid_usuario;
DELIMITER //
CREATE FUNCTION ch_integrid_usuario() RETURNS TINYINT
BEGIN
  DECLARE temp_hash VARCHAR(41);
  DECLARE codsuario BIGINT;
  DECLARE unombre VARCHAR(15);
  DECLARE utipo TINYINT;
  DECLARE uhash VARCHAR(41);
  
  DECLARE i_usuario CURSOR SELECT codigo_usuario,nombre,tipo_de_usuario,hash_user FROM usuarios;
  
  OPEN i_usuario;
  
usuario_loop: LOOP
  FETCH i_usuario into codsuario,unombre,utipo,uhash;
  SET temp_hash=encCRC(CONCAT(unombre,CONVERT(codsuario, UNSIGNED),CONVERT(utipo, UNSIGNED)));
  IF THEN
  LEAVE usuario_loop;
  END IF 
  END LOOP usuario_loop;
  CLOSE i_usuario;
RETURN 1;
END;
//
DELIMITER ;




DROP TRIGGER IF EXISTS t_adiciona_usuario;
DELIMITER //
CREATE TRIGGER t_adiciona_usuario BEFORE INSERT ON usuarios
  FOR EACH ROW BEGIN
      CALL insert_registro(0, 'Usuario adicionado');
  END
//
DELIMITER ;

###
### Devuelve la clave de un usuario
###
DROP FUNCTION IF EXISTS leer_pw;
DELIMITER //
CREATE FUNCTION leer_pw(unombre varchar(50)) RETURNS VARCHAR(41)
BEGIN
  DECLARE gpw VARCHAR(41) DEFAULT NULL;
  SELECT pw FROM usuarios WHERE nombre=unombre INTO gpw;
  RETURN gpw;
END
//
DELIMITER ;

###
### Cambia la clave de un usuario
###
DROP FUNCTION IF EXISTS cambiar_pw;
DELIMITER //
CREATE FUNCTION cambiar_pw(unombre varchar(50), oldpw varchar(41), newpw varchar(41)) RETURNS int
BEGIN
  DECLARE pw_cambiado int DEFAULT 0;
  DECLARE gpw_org VARCHAR(41);
  DECLARE oldpw_var VARCHAR(41) DEFAULT PASSWORD(Oldpw);
  DECLARE newpw_var VARCHAR(41) DEFAULT PASSWORD(newpw);
  SET gpw_org=leer_pw(unombre);
  IF oldpw_var=gpw_org THEN
    UPDATE usuarios SET pw=newpw_var WHERE nombre=unombre;
    SET pw_cambiado=1;
  ELSE
    SET pw_cambiado=0;
  END IF;
  RETURN pw_cambiado;
END;
//
DELIMITER ;


DROP TRIGGER IF EXISTS t_pw_usuario;
DELIMITER //
CREATE TRIGGER t_pw_usuario BEFORE UPDATE ON usuarios
  FOR EACH ROW BEGIN
      CALL insert_registro(0, 'Contraseña cambiada');
  END
//
DELIMITER ;


DROP FUNCTION IF EXISTS entrada_usuario;
DELIMITER //
CREATE FUNCTION entrada_usuario(unombre varchar(50), pw varchar(41)) RETURNS int
BEGIN

  SET @usuario_activo=unombre;
  RETURN 1;
END;
//
DELIMITER ;

