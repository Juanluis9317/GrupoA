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
    INSERT INTO Academico.PreRequisitos (Id_CursoRequisito, Id_CursoActual)
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

