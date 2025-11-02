USE Academia2022


ALTER TABLE Academico.Alumnos
	ALTER COLUMN CarreraID INT NOT NULL;
GO
-- Porque: Ayuda a que no se puedan agregar alumnos sin que posean una carreara ID por defecto y debeido a la FK solo se puede asinar a una carrera existente


-- CREAMOS TABLA PARA CONTROL DE CURSOS APROBADOS
CREATE TABLE Academico.CursosAprobados (
	IdCursoAprobado INT NOT NULL PRIMARY KEY IDENTITY,
	Id_Curso INT NOT NULL,
	Id_Alumno INT NOT NULL,
	Aprobado BIT NOT NULL DEFAULT 0,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaAprobado DATETIME NULL,
	CONSTRAINT Fk_CursosAproados_Cursos FOREIGN KEY (Id_Curso) REFERENCES Academico.Cursos(CursoID),
	CONSTRAINT Fk_CursosAprobados_Alumnos FOREIGN KEY (Id_Alumno) REFERENCES Academico.ALumnos(AlumnoID),
	CONSTRAINT UQ_CursosAprobados UNIQUE (Id_Curso, Id_Alumno)
);
GO
-- Porque?: Mejora al control de una tabla posterior llamada PreRequisitos


-- Creamos tabla para para llevar mejor control sobre los PreRequisitos de un curso
CREATE TABLE Academico.PreRequisitos(
	Id_PreRequisito INT NOT NULL PRIMARY KEY IDENTITY,
	Id_CursoRequisito INT,
	Id_CursoActual INT NOT NULL,
	CONSTRAINT FK_PreRequisitos_CursoRequisito FOREIGN KEY(Id_CursoRequisito) REFERENCES Academico.Cursos(CursoID),
	CONSTRAINT Fk_PreRequisitos_CursoNuevo FOREIGN KEY(Id_CursoActual) REFERENCES Academico.Cursos(CursoID),
	CONSTRAINT CK_CursosDistintos CHECK (Id_CursoRequisito <> Id_CursoActual)
);
GO


-- TRIGGER para crear automaticamente una tupla de Cursos Aprobados
CREATE TRIGGER tr_AgregarPreRequisito
ON Academico.Cursos
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Insertar prerequisito vac�o para cada curso nuevo
    INSERT INTO Academico.PreRequisitos (Id_CursoRequisito, Id_CursoActual, CreditosNecesarios)
    SELECT NULL, i.CursoID
    FROM INSERTED i;
END;
GO
-- Porque?: Automatiza la insersion de valores en esta tabla Cursos Aprobados, Evita que se generen errores por dupicados que no permite la 
-- CONSTRAINT UNIQUE en matriculas y CursosAprobados

-- Ayuda a mejorar 
ALTER TABLE Academico.Cursos
ADD Id_Carrera INT NOT NULL
    CONSTRAINT FK_Cursos_Carreras FOREIGN KEY (Id_Carrera) REFERENCES Academico.Carreras(CarreraID);
GO


-- Crea una tabla que almacena los cursos que se necesitan por carrera
CREATE TABLE Academico.CursosPorCarrera (
    Id_Curso INT NOT NULL,
    Id_Carrera INT NOT NULL,
    CONSTRAINT PK_CursosPorCarrera PRIMARY KEY (Id_Curso, Id_Carrera),
    CONSTRAINT FK_CursosPorCarrera_Curso FOREIGN KEY (Id_Curso) REFERENCES Academico.Cursos(CursoID),
    CONSTRAINT FK_CursosPorCarrera_Carrera FOREIGN KEY (Id_Carrera) REFERENCES Academico.Carreras(CarreraID)
);
GO
-- Porque?: Ayuda a buscar si los cursos se repiten por carrera lo que mantiene la normalizacion y agiliza consultas


-- Crea una tabla que suma los creditos totales de los cursos aprobados
CREATE TABLE Academico.CreditosAlumnos(
    IdCreditosAlumno INT PRIMARY KEY IDENTITY,
    TotalCreditos INT NOT NULL,
    Id_Alumno INT NOT NULL,
    Id_Carrera INT NOT NULL
    CONSTRAINT Fk_CreditosAlumnos_Alumnos FOREIGN KEY (Id_Alumno) REFERENCES Academico.Alumnos(AlumnoID),
    CONSTRAINT Fk_CreditosAlumnos_Carreras FOREIGN KEY (Id_Carrera) REFERENCES Academico.Carreras(CarreraID),
    CONSTRAINT UQ_CreditosAlumnos UNIQUE (Id_Carrera, Id_Alumno)  
);
GO


-- Actualiza el total de datos por alunos cuando este aprueba un curso
CREATE TRIGGER tr_ActualizarCreditosAlumnos
ON Academico.CursosAprobados
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Insertar nuevos registros en CreditosAlumnos si no existen
    INSERT INTO Academico.CreditosAlumnos (Id_Alumno, Id_Carrera, TotalCreditos)
    SELECT i.Id_Alumno, cc.Id_Carrera, c.CursoCreditosECTS
    FROM INSERTED i
    JOIN DELETED d ON i.IdCursoAprobado = d.IdCursoAprobado
    JOIN Academico.Cursos c ON c.CursoID = i.Id_Curso
    JOIN Academico.CursosPorCarrera cc ON cc.Id_Curso = c.CursoID
    WHERE d.Aprobado = 0 AND i.Aprobado = 1
    AND NOT EXISTS (
        SELECT 1
        FROM Academico.CreditosAlumnos ca
        WHERE ca.Id_Alumno = i.Id_Alumno AND ca.Id_Carrera = cc.Id_Carrera
    );

    -- 2. Actualizar TotalCreditos si el registro ya existe
    UPDATE ca
    SET ca.TotalCreditos = ca.TotalCreditos + c.CursoCreditosECTS
    FROM Academico.CreditosAlumnos ca
    JOIN INSERTED i ON ca.Id_Alumno = i.Id_Alumno
    JOIN DELETED d ON i.IdCursoAprobado = d.IdCursoAprobado
    JOIN Academico.Cursos c ON c.CursoID = i.Id_Curso
    JOIN Academico.CursosPorCarrera cc ON cc.Id_Curso = c.CursoID
    WHERE ca.Id_Carrera = cc.Id_Carrera
    AND d.Aprobado = 0 AND i.Aprobado = 1;
END;
GO
-- Porque: Automatiza procesos en la base de datos evitando que el usuario cometa errores


-- MODIFICACIONES NECESARIAS PARA CONTROL DE LOS ALUMNOS QUE CUMPLEN CON EL PREREQUISITO CREDITOS
ALTER TABLE Academico.PreRequisitos
    ADD CreditosNecesarios TINYINT DEFAULT 0;
GO
ALTER TABLE Academico.PreRequisitos
ADD CONSTRAINT UQ_PreRequisitos_CursoActual UNIQUE (Id_CursoActual);
GO


-- TRIGGER PARA COMPARAR SI EL ALUMNOS POSEE LOS CREDITOS NECESARIOS PARA ASIGNARSE EN UNA MATRICULA
CREATE TRIGGER tr_ValidarCreditosMatricula
ON Academico.Matriculas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Validar si el alumno tiene los cr�ditos necesarios para el curso
    IF EXISTS (
        SELECT 1
        FROM INSERTED i
        JOIN Academico.PreRequisitos pr ON i.CursoID = pr.Id_CursoActual
        JOIN Academico.CreditosAlumnos ca ON ca.Id_Alumno = i.AlumnoID
        WHERE ca.TotalCreditos < pr.CreditosNecesarios
    )
    BEGIN
        RAISERROR('El alumno no cumple con los creditos necesarios para matricularse en este curso.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO
-- Porque?: Necesario para mantener la logica de la base de datos y evitar errores humanos


-- Automatiza la creacion de Cursos Aprobados
CREATE TRIGGER tr_InsertarCursosAprobadosDesdeMatricula
ON Academico.Matriculas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Insertar en CursosAprobados solo si no existe ya la combinaci�n (Id_Curso, Id_Alumno)
    INSERT INTO Academico.CursosAprobados (Id_Curso, Id_Alumno)
    SELECT i.CursoID, i.AlumnoID
    FROM INSERTED i
    WHERE NOT EXISTS (
        SELECT 1
        FROM Academico.CursosAprobados ca
        WHERE ca.Id_Curso = i.CursoID AND ca.Id_Alumno = i.AlumnoID
    );
END;
GO
-- Porque?: Permite que un alumno no se quede sin registros de cursos Aprobados al final del semestre cuando se sincronizen todas las notas


-- Creamos una secuencia para su posterior uso
CREATE SEQUENCE Academico.SeqMatriculaID
START WITH 1 INCREMENT BY 1;
GO


-- Creamos una nueva columna en la tabla Matriculas, y le asignamos dicha columna el valor de la sequence
ALTER TABLE Academico.Matriculas
ADD IdMatricula INT NOT NULL
    CONSTRAINT DF_Matriculas_IdMatricula DEFAULT (NEXT VALUE FOR Academico.SeqMatriculaID);
GO
-- Porque?: Nos permite llevar un control mas especifico sobre la tabla Matriculas y respetamos la integridad de la tabla


-- Agregamos la restriccion UNIQUE a la columna para posteriormente poder usar este Id como llave foranea en otras tablas y crear relaciones
ALTER TABLE Academico.Matriculas
ADD CONSTRAINT UQ_Matriculas_IdMatricula UNIQUE (IdMatricula);
GO
-- Porque?: Puesto que la PK de matriculas es una llave compuesta, al tulizar UNIQUE garantizamos que esta columna se pueda usar como fk en otras tablas y evitamos ambiguedad de datos


--  Creamos una tabla quenos ayude a controlar si el alumno llego a la nota minima Necesaria para pasar el curso
CREATE TABLE Academico.AlumnosNotas(
    IdNota INT PRIMARY KEY NOT NULL IDENTITY,
    Id_Matricula INT NOT NULL,
    TotalNota TINYINT NOT NULL,
    CONSTRAINT Ck_TotalNota CHECK(TotalNota<=100),
    CONSTRAINT Fk_AlumnosNotas_CursosAprobados FOREIGN KEY (Id_Matricula) REFERENCES Academico.Matriculas(IdMatricula)  
);
GO
-- Porque?: Nos ayuda a mejorar el control que tenemos al momento de aprobar un alumno un curso
-- Nos garantiza saber cuando el alumno aprobo el curso5
-- Mejora la logica de la base de datos 
-- Mantiene su normalizacion haciendo que las actividades esten en una table aparte


-- Hace que cuando un alumno registre una nueva Matricula para un curso automaticamente se genere su tabla de notas
CREATE TRIGGER tr_InsertarNotaDesdeMatricula
ON Academico.Matriculas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Insertar nota inicial con TotalNota = 0 para cada nueva matr�cula
    INSERT INTO Academico.AlumnosNotas (Id_Matricula, TotalNota)
    SELECT i.IdMatricula, 0
    FROM INSERTED i;
END;
GO
-- Necesario para evitar problemas que la tupla no exista y luego le genere problemas al catedratico al momento de intentar ingresar una nota
-- Automatiza el proceso de creacion de esta tupla



-- Triger para cambiar el valor Aprobado en el curso de un alumno
CREATE TRIGGER tr_ActualizarEstadoAprobadoDesdeNota
ON Academico.AlumnosNotas
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ca
    SET ca.Aprobado = 1,
        ca.FechaAprobado = GETDATE()
    FROM Academico.CursosAprobados ca
    JOIN INSERTED i ON i.TotalNota >= 61
    JOIN Academico.Matriculas m ON m.IdMatricula = i.Id_Matricula
    WHERE ca.Id_Curso = m.CursoID
      AND ca.Id_Alumno = m.AlumnoID
      AND ca.Aprobado = 0;
END;
GO
-- Porque?: Automatiza el proceso de saber si un alumno Aprobo o no dicho curso
-- Evita posibles errores por el usuario
-- Mantiene la logica del sistema de cursos


-- Creamos una tabla que contiene las actividades hechas por un alumno en el transcurso del ciclo
CREATE TABLE Academico.CalendarioAcademico (
    IdActividad INT NOT NULL PRIMARY KEY IDENTITY,
    NombreActividad VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(150),
    ValorNota NUMERIC(4, 2) DEFAULT NULL,
    FechaInicio DATETIME2 NOT NULL DEFAULT GETDATE(),
    FechaFin DATETIME2 NULL,
    Id_Matricula INT NOT NULL,
    Id_AlunonsNotas INT NOT NULL,
    CONSTRAINT Ck_CalendarioAcademico CHECK(FechaFin >= FechaInicio),
    CONSTRAINT Fk_CalendarioAcademico_Matriculas FOREIGN KEY (Id_Matricula) REFERENCES Academico.Matriculas(IdMatricula)
);
GO
-- Porque?: Ayuda a mantener la normalizacion en las tablas evitando que se repitan datos dentro de la tabla AlumnosNotas
-- Permite separar de forma organizada, las actividades, Parciales o examen final
-- Se amarra directamente a la matricula lo que permite detallar el rednidmiento del alumno
-- Asegura que el catedratico tenga que asignar distintas actividades dejando a criterio del catedratico el valor de cada actividad
-- Permite asignar notas mas especificas dentro de cada actividad utilizando datos decimales 


-- Triger que controla el total de nota que llegara a la tabla AlumnosNotas
CREATE TRIGGER tr_ValidarNotaActividad
ON Academico.CalendarioAcademico
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que la suma de ValorNota no exceda 100
    IF EXISTS (
        SELECT 1
        FROM INSERTED i
        WHERE i.ValorNota IS NOT NULL
        AND (
            ISNULL((
                SELECT SUM(ValorNota)
                FROM Academico.CalendarioAcademico
                WHERE Id_AlunonsNotas = i.Id_AlunonsNotas
            ), 0) + i.ValorNota > 100
        )
    )
    BEGIN
        RAISERROR('La suma de las notas supera el l�mite de 100 puntos.', 16, 1);
        RETURN;
    END

    -- Si pasa la validaci�n, insertar normalmente
    INSERT INTO Academico.CalendarioAcademico (NombreActividad, Descripcion, ValorNota, FechaInicio, FechaFin, Id_Matricula, Id_AlunonsNotas)
    SELECT NombreActividad, Descripcion, ValorNota, FechaInicio, FechaFin, Id_Matricula, Id_AlunonsNotas 
    FROM INSERTED;
END;
GO
-- Porque?: Evita que el total de actividades superen los 100 puntos
-- Automatiza el control sobre la nota final que tendra el estudiante
-- Evita que se produzcan errores humanos al momento de asignar notas
-- Permite que el catedratico asigne actividades para que el alumno pueda ganar puntos extra


-- Sp para cerrar las notas al final del semestre
CREATE PROCEDURE Academico.sp_SincronizarNotasAlumnos
AS
BEGIN
    SET NOCOUNT ON;
    -- Actualizar TotalNota en AlumnosNotas con la suma de ValorNota desde CalendarioAcademico
    UPDATE an
    SET an.TotalNota = 
        CASE 
            WHEN SUMA.NotaTotal > 100 THEN 100
            ELSE SUMA.NotaTotal
        END
    FROM Academico.AlumnosNotas an
    INNER JOIN (
        SELECT
            Id_AlunonsNotas,
            CAST(SUM(CAST(ValorNota AS INT)) AS INT) AS NotaTotal
        FROM Academico.CalendarioAcademico
        WHERE ValorNota IS NOT NULL
        GROUP BY Id_AlunonsNotas
    ) AS SUMA ON SUMA.Id_AlunonsNotas = an.IdNota;
END;
GO
-- Porque?: Permite sincronizar el total acumulado de las notas al final del semestre y almacenarlo en la tabla AlumnosNotas
-- Realiza conversion de datos dentro de la tabla CalendarioAcademico para que al final se agregue un valor entero dentro de la tabla AlumnosNotas
-- Permite que se activen triggers que mantienen la veracidad de los datos en la tabla gantizando saber cuando un alumno aprobo
-- Evita ejecuciones inesperadas y realizar modificaciones innecesarias dentro de la tabla por uso de triggers


