/*
=========================================================================
 SCRIPT DE CREACIÓN DE BASE DE DATOS: Academia2022 (v2 - Corregido)
=========================================================================
 Propósito: Genera la estructura completa de la base de datos.
 Corrección: Añadidos 'GO' después de los 'PRINT' que preceden a
             CREATE SCHEMA, CREATE VIEW, CREATE FUNCTION, etc.,
             para evitar el error 111.
=========================================================================
*/
USE master;
GO

-- 1. Reiniciar la base de datos para idempotencia
IF DB_ID('Academia2022') IS NOT NULL
BEGIN
    ALTER DATABASE Academia2022 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Academia2022;
    PRINT 'Base de datos Academia2022 anterior eliminada.';
END
GO

CREATE DATABASE Academia2022;
GO
PRINT 'Base de datos Academia2022 creada.';
USE Academia2022;
GO

-- 2. Habilitar RCSI (Nivel de aislamiento)
ALTER DATABASE Academia2022 SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
PRINT 'Nivel de aislamiento READ_COMMITTED_SNAPSHOT habilitado.';
GO

-- 3. Creación de Esquemas
PRINT 'Creando esquemas...';
GO -- <<-- CORRECCIÓN: GO añadido aquí

CREATE SCHEMA Academico; -- alumnos, cursos, carreras, matrículas
GO
CREATE SCHEMA Seguridad; -- usuarios, roles, auditoría
GO
CREATE SCHEMA App;       -- vistas expuestas a la aplicación
GO
CREATE SCHEMA Lab;       -- objetos auxiliares de práctica
GO
PRINT 'Esquemas (Academico, Seguridad, App, Lab) creados.';

-- =========================================================================
-- 4. Creación de Tablas Base y Restricciones
-- (Estas no necesitan GOs extra porque CREATE TABLE no tiene esa restricción)
-- =========================================================================

PRINT 'Creando tabla Academico.Alumnos...';
CREATE TABLE Academico.Alumnos(
    AlumnoID INT IDENTITY (1,1) CONSTRAINT PK_Alumnos PRIMARY KEY,
    AlumnoNombre NVARCHAR (60) NOT NULL,
    AlumnoApellido NVARCHAR (60) NOT NULL,
    AlumnoEdad TINYINT NOT NULL CONSTRAINT CK_Alumno_Edad CHECK (AlumnoEdad>=16),
    AlumnoActivo BIT NOT NULL CONSTRAINT DF_Alumno_Activo DEFAULT (1)
);
GO

PRINT 'Creando tabla Academico.Carreras...';
CREATE TABLE Academico.Carreras(
    CarreraID INT IDENTITY (1,1) CONSTRAINT PK_Carreras PRIMARY KEY,
    CarreraNombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Carreras_Nombre UNIQUE
);
GO

PRINT 'Añadiendo FK CarreraID a Alumnos (ON DELETE SET NULL)...';
ALTER TABLE Academico.Alumnos
ADD CarreraID INT NULL CONSTRAINT FK_Alumnos_Carreras
    FOREIGN KEY (CarreraID) REFERENCES Academico.Carreras(CarreraID)
    ON DELETE SET NULL ON UPDATE NO ACTION;
GO

PRINT 'Creando tabla Academico.Cursos...';
CREATE TABLE Academico.Cursos(
    CursoID INT IDENTITY(1,1) CONSTRAINT PK_Cursos PRIMARY KEY,
    CursoNombre NVARCHAR(100) NOT NULL CONSTRAINT UQ_Cursos_Nombre UNIQUE,
    CursoCreditos TINYINT NOT NULL CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditos BETWEEN 1 AND 10)
);
GO

PRINT 'Creando tabla Academico.Matriculas...';
CREATE TABLE Academico.Matriculas(
    AlumnoID INT NOT NULL,
    CursoID INT NOT NULL,
    MatriculaPeriodo CHAR(4) NOT NULL CONSTRAINT CK_Matriculas_Periodo
        CHECK (MatriculaPeriodo LIKE '[12][0-9][S][12]'), -- Formato '24S1', '25S2'
    CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, MatriculaPeriodo),
    CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID)
        REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
    CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID)
        REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE
);
GO

PRINT 'Creando tabla Academico.Contactos (Normalización)...';
CREATE TABLE Academico.Contactos(
    ContactoID INT IDENTITY(1,1) CONSTRAINT PK_Contactos PRIMARY KEY,
    Email      NVARCHAR(120) NULL CONSTRAINT UQ_Contactos_Email UNIQUE,
    Telefono   VARCHAR(20)   NULL
);
GO

PRINT 'Añadiendo FK ContactoID a Alumnos...';
ALTER TABLE Academico.Alumnos
ADD ContactoID INT NULL
    CONSTRAINT FK_Alumnos_Contactos
    FOREIGN KEY (ContactoID) REFERENCES Academico.Contactos(ContactoID);
GO

PRINT 'Creando tabla Academico.AlumnoIdiomas (N:M)...';
CREATE TABLE Academico.AlumnoIdiomas(
    AlumnoID INT NOT NULL,
    Idioma   NVARCHAR(40) NOT NULL,
    Nivel    NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_AlumnoIdiomas PRIMARY KEY (AlumnoID, Idioma),
    CONSTRAINT FK_AI_Alumno FOREIGN KEY (AlumnoID)
        REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
GO

-- =========================================================================
-- 5. Modificaciones DDL (Columnas calculadas, renombradas, secuencias)
-- =========================================================================

PRINT 'Añadiendo columna calculada NombreCompleto a Alumnos...';
ALTER TABLE Academico.Alumnos
ADD NombreCompleto AS (AlumnoNombre + N' ' + AlumnoApellido) PERSISTED;
GO
CREATE INDEX IX_Alumnos_NombreCompleto ON Academico.Alumnos(NombreCompleto);
PRINT 'Índice creado en NombreCompleto.';
GO

PRINT 'Renombrando CursoCreditos a CursoCreditosECTS...';
-- 1. Quitar restricción
ALTER TABLE Academico.Cursos
DROP CONSTRAINT CK_Cursos_Creditos;
GO
-- 2. Renombrar columna
EXEC sp_rename
    'Academico.Cursos.CursoCreditos',
    'CursoCreditosECTS',
    'COLUMN';
GO
-- 3. Volver a añadir restricción con el nuevo nombre
ALTER TABLE Academico.Cursos
ADD CONSTRAINT CK_Cursos_CreditosECTS CHECK (CursoCreditosECTS BETWEEN 1 AND 10);
PRINT 'Columna renombrada y constraint CK_Cursos_CreditosECTS recreado.';
GO

PRINT 'Creando Secuencia para Códigos de Curso...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE SEQUENCE Academico.SeqCodigoCurso AS INT START WITH 1000 INCREMENT BY 1;
GO
ALTER TABLE Academico.Cursos
ADD CursoCodigo INT NOT NULL
    CONSTRAINT DF_Cursos_CursoCodigo DEFAULT (NEXT VALUE FOR Academico.SeqCodigoCurso);
PRINT 'Columna CursoCodigo añadida a Cursos con DEFAULT de secuencia.';
GO

-- =========================================================================
-- 6. Índices Adicionales
-- =========================================================================

PRINT 'Creando índice optimizado en Matriculas (CursoID, MatriculaPeriodo)...';
CREATE INDEX IX_Matriculas_Cursos_MatriculaPeriodo
ON Academico.Matriculas(CursoID, MatriculaPeriodo)
INCLUDE (AlumnoID);
GO

-- =========================================================================
-- 7. Objetos de Esquema Lab (JSON, SPARSE, Temporal)
-- =========================================================================

PRINT 'Creando Lab.Eventos (con CHECK ISJSON)...';
CREATE TABLE Lab.Eventos(
    Id INT IDENTITY(1,1) CONSTRAINT PK_Eventos PRIMARY KEY,
    Payload NVARCHAR(MAX) NOT NULL,
    CONSTRAINT CK_Eventos_Payload CHECK (ISJSON(Payload) = 1)
);
GO

PRINT 'Creando Lab.AlumnoRedes (con columnas SPARSE)...';
CREATE TABLE Lab.AlumnoRedes(
    AlumnoID INT NOT NULL,
    Twitter  NVARCHAR(50) SPARSE NULL,
    Instagram NVARCHAR(50) SPARSE NULL,
    CONSTRAINT FK_Redes_Alumno FOREIGN KEY (AlumnoID)
        REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
GO

PRINT 'Habilitando System-Versioning (Temporal) en Lab.Eventos...';
ALTER TABLE Lab.Eventos
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
        CONSTRAINT DF_Eventos_From DEFAULT SYSUTCDATETIME(),
    ValidTo   DATETIME2 GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL
        CONSTRAINT DF_Eventos_To   DEFAULT CONVERT(DATETIME2,'9999-12-31'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
ALTER TABLE Lab.Eventos
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Lab.Eventos_Hist));
PRINT 'Tabla Lab.Eventos_Hist creada y versionado habilitado.';
GO

-- =========================================================================
-- 8. Vistas (Capa de Aplicación)
-- =========================================================================

PRINT 'Creando vista App.vw_ResumenAlumno...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE VIEW App.vw_ResumenAlumno
AS
SELECT a.AlumnoID, a.NombreCompleto, a.AlumnoEdad, a.CarreraID
FROM Academico.Alumnos a
WHERE a.AlumnoActivo = 1;
GO

PRINT 'Creando vista indexada App.vw_MatriculasPorCurso...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE VIEW App.vw_MatriculasPorCurso
WITH SCHEMABINDING
AS
SELECT m.CursoID, COUNT_BIG(*) AS Total
FROM Academico.Matriculas AS m
GROUP BY m.CursoID;
GO
CREATE UNIQUE CLUSTERED INDEX IX_vw_MatriculasPorCurso
ON App.vw_MatriculasPorCurso(CursoID);
PRINT 'Vista indexada creada exitosamente.';
GO

-- =========================================================================
-- 9. Seguridad (DCL - Logins, Usuarios, Roles, Permisos)
-- =========================================================================

PRINT 'Configurando seguridad (Login, User, Roles)...';
GO
USE master;
IF SUSER_ID('app_ro') IS NOT NULL DROP LOGIN app_ro;
CREATE LOGIN app_ro WITH PASSWORD = 'Str0ng_P@ssw0rd!'; -- Cambiar en producción
GO
USE Academia2022;
IF USER_ID('app_ro') IS NOT NULL DROP USER app_ro;
CREATE USER app_ro FOR LOGIN app_ro WITH DEFAULT_SCHEMA = App;
GO
-- Permiso básico de lectura
EXEC sp_addrolemember N'db_datareader', N'app_ro';
GO
-- Rol personalizado para reportes
PRINT 'Creando rol rol_reportes...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE ROLE rol_reportes;
PRINT 'Rol rol_reportes creado.';
GO
-- Permiso granular al rol (más simple que vista por vista)
GRANT SELECT ON SCHEMA::App TO rol_reportes;
PRINT 'Permiso SELECT en SCHEMA::App otorgado a rol_reportes.';
GO
-- Asignar rol al usuario
EXEC sp_addrolemember 'rol_reportes', 'app_ro';
GO
-- Denegar acceso directo a tablas base
DENY SELECT ON OBJECT::Academico.Alumnos TO app_ro;
PRINT 'Acceso directo a Academico.Alumnos denegado a app_ro.';
GO

-- Sinónimo para compatibilidad
PRINT 'Creando sinónimo dbo.Matriculas...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE SYNONYM dbo.Matriculas FOR Academico.Matriculas;
PRINT 'Sinónimo dbo.Matriculas creado.';
GO

-- =========================================================================
-- 10. Seguridad Avanzada (RLS - Row Level Security)
-- =========================================================================
PRINT 'Configurando Row-Level Security (RLS)...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
-- RLS debe estar en su propio esquema de seguridad
CREATE SCHEMA Sec;
GO

PRINT 'Creando función de predicado RLS...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE FUNCTION Sec.fn_AlumnosActivos(@Activo bit)
RETURNS TABLE
WITH SCHEMABINDING
AS
-- El predicado de filtro debe ser 1 (permite) o 0 (deniega)
-- Asumimos que la app (app_ro) solo debe ver activos.
-- Para otros usuarios (ej. 'dbo') no se aplica filtro.
RETURN SELECT 1 AS AllowRow
       WHERE @Activo = 1 OR USER_NAME() <> 'app_ro';
GO

PRINT 'Creando política de seguridad RLS...';
GO -- <<-- CORRECCIÓN: GO añadido aquí
CREATE SECURITY POLICY Sec.Policy_Alumnos_Activos
ADD FILTER PREDICATE Sec.fn_AlumnosActivos(AlumnoActivo)
ON Academico.Alumnos
WITH (STATE = ON);
PRINT 'Política de seguridad RLS Sec.Policy_Alumnos_Activos aplicada a Alumnos.';
GO

-- =========================================================================
-- 11. Auditoría (Opcional - Requiere permisos de servidor)
-- =========================================================================

PRINT N'--- Configurando Auditoría (Requiere permisos de Servidor) ---';
PRINT N'ADVERTENCIA: Verifique que la ruta C:\SQLAudit\ exista o edite el script.';
USE master;
GO

-- <<-- CORRECCIÓN: Añadido IF NOT EXISTS para evitar error si ya existe
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'Audit_Academia')
BEGIN
    PRINT 'Creando Auditoría de Servidor...';
    CREATE SERVER AUDIT Audit_Academia
    TO FILE (FILEPATH = 'C:\SQLAudit\'); -- !! AJUSTAR RUTA !!
END
ELSE
BEGIN
    PRINT 'Auditoría de Servidor ya existía.';
END
GO

ALTER SERVER AUDIT Audit_Academia WITH (STATE = ON);
PRINT 'Auditoría de Servidor activada.';
GO

USE Academia2022;
GO
-- <<-- CORRECCIÓN: Añadido IF NOT EXISTS para evitar error si ya existe
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'Audit_AcademiaDB')
BEGIN
    PRINT 'Creando Especificación de Auditoría de Base de Datos...';
    CREATE DATABASE AUDIT SPECIFICATION Audit_AcademiaDB
    FOR SERVER AUDIT Audit_Academia
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP), -- Cambios de GRANT/DENY/REVOKE
    ADD (FAILED_DATABASE_AUTHENTICATION_GROUP) -- Logins fallidos a esta DB
    WITH (STATE = ON);
END
ELSE
BEGIN
    PRINT 'Especificación de Auditoría de Base de Datos ya existía.';
    ALTER DATABASE AUDIT SPECIFICATION Audit_AcademiaDB WITH (STATE = ON);
END
GO
PRINT 'Especificación de Auditoría de Base de Datos activada.';
GO

PRINT '=====================================================';
PRINT ' Script DDL de Academia2022 completado exitosamente.';
PRINT '=====================================================';