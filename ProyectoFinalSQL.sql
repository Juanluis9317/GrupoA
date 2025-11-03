


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
        RAISERROR('La suma de las notas supera el límite de 100 puntos.', 16, 1);
        RETURN;
    END

    -- Si pasa la validación, insertar normalmente
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