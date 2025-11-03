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
